-- =====================================================================
-- MoMo SMS Data Processing System — Database Setup
-- Engine: MySQL 8.0+
-- File: database/database_setup.sql
--
-- Contents:
--   1. Database creation
--   2. Table DDL (Users, Transaction_Categories, Raw_SMS_Log,
--      Transactions, Transaction_Participants, System_Logs)
--   3. Indexes for performance
--   4. Sample data (5+ rows per main table, drawn from modified_sms_v2.xml)
-- =====================================================================

DROP DATABASE IF EXISTS momo_sms_system;
CREATE DATABASE momo_sms_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE momo_sms_system;

-- ---------------------------------------------------------------------
-- 1. USERS
-- Sender / receiver / agent / merchant identities extracted from SMS text
-- ---------------------------------------------------------------------
CREATE TABLE Users (
    user_id             INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique ID for a person/agent/merchant found in the SMS text',
    full_name           VARCHAR(100) NOT NULL COMMENT 'Name as it appears in the SMS body',
    phone_number        VARCHAR(15)  NOT NULL COMMENT 'MSISDN, may be partially masked in source data',
    user_category       VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER'
                            COMMENT 'Role this identity plays in the MoMo ecosystem',
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this identity was first seen',
    CONSTRAINT uq_users_phone UNIQUE (phone_number),
    CONSTRAINT chk_users_phone_len CHECK (CHAR_LENGTH(phone_number) >= 6),
    CONSTRAINT chk_user_category CHECK (user_category IN ('CUSTOMER','AGENT','MERCHANT'))
) ENGINE=InnoDB COMMENT='Customers, agents and merchants referenced by MoMo transactions';

-- ---------------------------------------------------------------------
-- 2. TRANSACTION_CATEGORIES
-- Lookup table: keeps categorization logic data-driven, not hardcoded
-- ---------------------------------------------------------------------
CREATE TABLE Transaction_Categories (
    category_id     INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique ID for a transaction category',
    category_code   VARCHAR(30)  NOT NULL COMMENT 'Machine-readable code used by the ETL parser',
    category_name   VARCHAR(60)  NOT NULL COMMENT 'Human-readable label',
    description     VARCHAR(255) NULL COMMENT 'What kind of SMS pattern maps to this category',
    is_debit        BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'TRUE if this category reduces account balance',
    CONSTRAINT uq_category_code UNIQUE (category_code)
) ENGINE=InnoDB COMMENT='Reference list of MoMo transaction types (payment, transfer, deposit, etc.)';

-- ---------------------------------------------------------------------
-- 3. RAW_SMS_LOG
-- Source-of-truth raw records before ETL parsing. Not every row becomes
-- a transaction (e.g. OTP messages), hence the is_parsed flag.
-- ---------------------------------------------------------------------
CREATE TABLE Raw_SMS_Log (
    sms_id          INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique ID for a raw SMS record',
    sender_address  VARCHAR(30) NOT NULL COMMENT 'SMS sender address, e.g. M-Money',
    raw_body        TEXT NOT NULL COMMENT 'Full untouched SMS body text',
    sms_date        DATETIME NOT NULL COMMENT 'Timestamp the SMS was received (from readable_date)',
    is_parsed       BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'TRUE once ETL has successfully extracted a transaction'
) ENGINE=InnoDB COMMENT='Immutable staging table holding every ingested SMS prior to parsing';

-- ---------------------------------------------------------------------
-- 4. TRANSACTIONS
-- Core fact table: one confirmed MoMo transaction
-- ---------------------------------------------------------------------
CREATE TABLE Transactions (
    transaction_id      INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique ID for a transaction',
    amount              DECIMAL(12,2) NOT NULL COMMENT 'Transaction amount in RWF',
    transaction_time    DATETIME NOT NULL COMMENT 'Date/time the transaction was completed',
    processed_by        VARCHAR(30) NULL COMMENT 'Who processed the transaction: SYSTEM, AGENT, or agent name from the SMS',
    status              VARCHAR(20) NOT NULL DEFAULT 'COMPLETED'
                            COMMENT 'Final state of the transaction',
    category_id         INT NOT NULL COMMENT 'FK -> Transaction_Categories.category_id',
    fee                 DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Fee charged for the transaction in RWF',
    balance_after       DECIMAL(12,2) NULL COMMENT 'Account balance immediately after the transaction',
    CONSTRAINT fk_tx_category FOREIGN KEY (category_id) REFERENCES Transaction_Categories(category_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_tx_amount_positive CHECK (amount > 0),
    CONSTRAINT chk_tx_fee_nonnegative CHECK (fee >= 0),
    CONSTRAINT chk_tx_status CHECK (status IN ('COMPLETED','FAILED','REVERSED'))
) ENGINE=InnoDB COMMENT='Core fact table of confirmed/failed/reversed MoMo transactions';

-- ---------------------------------------------------------------------
-- 5. TRANSACTION_PARTICIPANTS  (junction table — resolves M:N)
-- A transaction can involve multiple users in different roles
-- (sender, receiver, agent); a user appears across many transactions.
-- ---------------------------------------------------------------------
CREATE TABLE Transaction_Participants (
    participant_id      INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique ID for a participation record',
    transaction_id      INT NOT NULL COMMENT 'FK -> Transactions.transaction_id',
    user_id             INT NOT NULL COMMENT 'FK -> Users.user_id',
    participant_role    VARCHAR(20) NOT NULL COMMENT 'Role this user plays in the transaction',
    CONSTRAINT fk_participant_tx FOREIGN KEY (transaction_id) REFERENCES Transactions(transaction_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_participant_user FOREIGN KEY (user_id) REFERENCES Users(user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_participant_tx_user UNIQUE (transaction_id, user_id),
    CONSTRAINT chk_participant_role CHECK (participant_role IN ('SENDER','RECEIVER','AGENT'))
) ENGINE=InnoDB COMMENT='Junction table resolving the M:N relationship between Users and Transactions';

-- ---------------------------------------------------------------------
-- 6. SYSTEM_LOGS
-- ETL pipeline observability: one row per processing step/outcome
-- ---------------------------------------------------------------------
CREATE TABLE System_Logs (
    log_id          INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique ID for a log entry',
    related_sms_id  INT NULL COMMENT 'FK -> Raw_SMS_Log.sms_id, the record being processed',
    process_step    VARCHAR(40) NOT NULL COMMENT 'ETL stage, e.g. PARSE, CATEGORIZE, LOAD',
    status          VARCHAR(10) NOT NULL COMMENT 'Outcome of this processing step (SUCCESS or FAILED)',
    message         VARCHAR(255) NULL COMMENT 'Detail message or error text',
    logged_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this log entry was written',
    CONSTRAINT fk_log_sms FOREIGN KEY (related_sms_id) REFERENCES Raw_SMS_Log(sms_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_log_status CHECK (status IN ('SUCCESS','FAILED'))
) ENGINE=InnoDB COMMENT='ETL pipeline processing log for traceability and debugging';

-- =====================================================================
-- INDEXES — strategic, beyond what PK/UNIQUE already provide
-- =====================================================================
CREATE INDEX idx_users_phone            ON Users(phone_number);
CREATE INDEX idx_tx_time                ON Transactions(transaction_time);
CREATE INDEX idx_tx_category            ON Transactions(category_id);
CREATE INDEX idx_tx_status              ON Transactions(status);
CREATE INDEX idx_participants_user      ON Transaction_Participants(user_id);
CREATE INDEX idx_participants_tx        ON Transaction_Participants(transaction_id);
CREATE INDEX idx_logs_status            ON System_Logs(status);
CREATE INDEX idx_logs_sms               ON System_Logs(related_sms_id);

-- =====================================================================
-- SAMPLE DATA — drawn from modified_sms_v2.xml
-- =====================================================================

-- Users (account owner, 4 known contacts, 2 agents, 2 merchants) = 9 rows
INSERT INTO Users (full_name, phone_number, user_category) VALUES
('Abebe Chala Chebudie', '250795963036', 'CUSTOMER'),   -- the account owner
('Jane Smith',           '250789013000', 'CUSTOMER'),
('Samuel Carter',        '250791666666', 'CUSTOMER'),
('Alex Doe',             '250790777777', 'CUSTOMER'),
('Robert Brown',         '250788999999', 'CUSTOMER'),
('Linda Green',          '250790777778', 'CUSTOMER'),
('Agent Sophia',         '250790777779', 'AGENT'),
('IREMBO Ltd',           '250700000001', 'MERCHANT'),
('ESICIA LTD KPAY',      '250700000002', 'MERCHANT');

-- Transaction_Categories = 10 rows
INSERT INTO Transaction_Categories (category_code, category_name, description, is_debit) VALUES
('INCOMING_MONEY',     'Incoming Money',        'Money received from another user',                    FALSE),
('TRANSFER_SEND',      'Mobile Transfer',       'P2P transfer sent to another mobile number',          TRUE),
('MERCHANT_PAYMENT',   'Merchant Payment',      'Payment to a merchant / code holder',                 TRUE),
('AIRTIME_PAYMENT',    'Airtime Purchase',      'Airtime top-up payment',                              TRUE),
('BUNDLE_PURCHASE',    'Bundle Purchase',       'Data or voice bundle purchase',                       TRUE),
('BANK_DEPOSIT',       'Bank Deposit',          'Cash/bank deposit into MoMo account',                 FALSE),
('AGENT_WITHDRAWAL',   'Agent Cash Withdrawal', 'Cash withdrawn from an agent',                        TRUE),
('BANK_TRANSFER',      'Linked Bank Transfer',  'Transfer to/from a linked bank account',              TRUE),
('REVERSAL',           'Transaction Reversal',  'A previous transaction was reversed',                 FALSE),
('FAILED_TRANSACTION', 'Failed Transaction',    'Transaction attempted but not completed',             FALSE);

-- Raw_SMS_Log = 6 rows (verbatim excerpts from modified_sms_v2.xml)
INSERT INTO Raw_SMS_Log (sender_address, raw_body, sms_date, is_parsed) VALUES
('M-Money', 'You have received 2000 RWF from Jane Smith (*********013) on your mobile money account at 2024-05-10 16:30:51. Your new balance:2000 RWF. Financial Transaction Id: 76662021700.', '2024-05-10 16:30:58', TRUE),
('M-Money', 'TxId: 73214484437. Your payment of 1,000 RWF to Jane Smith 12845 has been completed at 2024-05-10 16:31:39. Your new balance: 1,000 RWF. Fee was 0 RWF.', '2024-05-10 16:31:46', TRUE),
('M-Money', '*113*R*A bank deposit of 40000 RWF has been added to your mobile money account at 2024-05-11 18:43:49. Your NEW BALANCE :40400 RWF. Cash Deposit::CASH::::0::250795963036.', '2024-05-11 18:45:36', TRUE),
('M-Money', '*165*S*10000 RWF transferred to Samuel Carter (250791666666) from 36521838 at 2024-05-11 20:34:47 . Fee was: 100 RWF. New balance: 28300 RWF.', '2024-05-11 20:34:55', TRUE),
('M-Money', 'You Abebe Chala CHEBUDIE (*********036) have via agent: Agent Sophia (250790777779), withdrawn 20000 RWF from your mobile money account: 36521838 at 2024-11-23 13:23:44.', '2024-11-23 13:23:51', TRUE),
('M-Money', '<#> Dear Customer, your MTN MoMo application one-time password is :2476. MTN MoMo does not recommend that you share or expose your one-time password with anyone.', '2024-06-06 09:12:00', FALSE);

-- Transactions = 5 rows
INSERT INTO Transactions (category_id, amount, fee, balance_after, transaction_time, status, processed_by) VALUES
((SELECT category_id FROM Transaction_Categories WHERE category_code='INCOMING_MONEY'),   2000.00,   0.00, 2000.00,  '2024-05-10 16:30:51', 'COMPLETED', 'SYSTEM'),
((SELECT category_id FROM Transaction_Categories WHERE category_code='MERCHANT_PAYMENT'), 1000.00,   0.00, 1000.00,  '2024-05-10 16:31:39', 'COMPLETED', 'SYSTEM'),
((SELECT category_id FROM Transaction_Categories WHERE category_code='BANK_DEPOSIT'),     40000.00,  0.00, 40400.00, '2024-05-11 18:43:49', 'COMPLETED', 'SYSTEM'),
((SELECT category_id FROM Transaction_Categories WHERE category_code='TRANSFER_SEND'),    10000.00, 100.00, 28300.00, '2024-05-11 20:34:47', 'COMPLETED', 'SYSTEM'),
((SELECT category_id FROM Transaction_Categories WHERE category_code='AGENT_WITHDRAWAL'), 20000.00,  0.00, NULL,      '2024-11-23 13:23:44', 'COMPLETED', 'AGENT');

-- Transaction_Participants = 8 rows covering all 5 transactions
INSERT INTO Transaction_Participants (transaction_id, user_id, participant_role) VALUES
(1, (SELECT user_id FROM Users WHERE full_name='Jane Smith'),             'SENDER'),
(1, (SELECT user_id FROM Users WHERE full_name='Abebe Chala Chebudie'),   'RECEIVER'),
(2, (SELECT user_id FROM Users WHERE full_name='Abebe Chala Chebudie'),   'SENDER'),
(2, (SELECT user_id FROM Users WHERE full_name='Jane Smith'),             'RECEIVER'),
(3, (SELECT user_id FROM Users WHERE full_name='Abebe Chala Chebudie'),   'RECEIVER'),
(4, (SELECT user_id FROM Users WHERE full_name='Abebe Chala Chebudie'),   'SENDER'),
(4, (SELECT user_id FROM Users WHERE full_name='Samuel Carter'),          'RECEIVER'),
(5, (SELECT user_id FROM Users WHERE full_name='Abebe Chala Chebudie'),   'SENDER'),
(5, (SELECT user_id FROM Users WHERE full_name='Agent Sophia'),           'AGENT');

-- System_Logs = 6 rows (5 successful parses + 1 skip for the OTP message)
INSERT INTO System_Logs (related_sms_id, process_step, status, message) VALUES
(1, 'PARSE',       'SUCCESS', 'Extracted incoming_money transaction'),
(2, 'PARSE',       'SUCCESS', 'Extracted merchant_payment transaction'),
(3, 'PARSE',       'SUCCESS', 'Extracted bank_deposit transaction'),
(4, 'CATEGORIZE',  'SUCCESS', 'Matched pattern TRANSFER_SEND via regex "transferred to"'),
(5, 'LOAD',        'SUCCESS', 'Inserted agent_withdrawal transaction and 2 participants'),
(6, 'PARSE',       'FAILED',  'SMS classified as non-transactional (OTP) - skipped from Transactions');
