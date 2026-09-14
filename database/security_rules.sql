-- =====================================================================
-- Security & Data-Accuracy Rules — MoMo SMS Data Processing System
-- File: database/security_rules.sql
-- Run this AFTER database_setup.sql
-- =====================================================================

USE momo_sms_system;

-- ---------------------------------------------------------------------
-- RULE 1 — Least-privilege application accounts
-- Three separate MySQL users instead of one shared root/app login.
-- DROP USER first so re-runs always start from a clean, known state
-- (stale grants from earlier script versions can never leak through).
--
-- Dev password 'Maureen123!' satisfies MySQL's default
-- validate_password MEDIUM policy (mixed case + digit + special char).
-- Replace with a strong secret before any non-local deployment.
-- ---------------------------------------------------------------------

-- Read-only account for the reporting/dashboard layer — cannot modify data.
-- Granted SELECT on each table individually (NOT on Users/raw data — PII),
-- plus the masking view below, so dashboards can never see full phone numbers.
DROP USER IF EXISTS 'momo_readonly'@'%';
CREATE USER 'momo_readonly'@'%' IDENTIFIED BY 'Maureen123!';
GRANT SELECT ON momo_sms_system.Transaction_Categories TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.Raw_SMS_Log TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.Transactions TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.Transaction_Participants TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.System_Logs TO 'momo_readonly'@'%';

-- ETL account — can insert/update staging + core tables, but cannot DELETE
-- (deletion of financial records should never be an automated ETL action).
-- DELETE is simply not granted — least privilege, nothing extra to revoke.
DROP USER IF EXISTS 'momo_etl'@'%';
CREATE USER 'momo_etl'@'%' IDENTIFIED BY 'Maureen123!';
GRANT SELECT, INSERT, UPDATE ON momo_sms_system.* TO 'momo_etl'@'%';

-- Admin account — full privileges, used only for maintenance
DROP USER IF EXISTS 'momo_admin'@'%';
CREATE USER 'momo_admin'@'%' IDENTIFIED BY 'Maureen123!';
GRANT ALL PRIVILEGES ON momo_sms_system.* TO 'momo_admin'@'%';

FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------
-- RULE 2 — Data masking view for PII
-- Reporting/dashboard queries should never see full phone numbers.
-- Expose only this view to 'momo_readonly', not the base Users table.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW View_Users_Masked AS
SELECT
    user_id,
    full_name,
    CONCAT('*******', RIGHT(phone_number, 4)) AS phone_number_masked,
    user_category,
    created_at
FROM Users;

GRANT SELECT ON momo_sms_system.View_Users_Masked TO 'momo_readonly'@'%';

-- ---------------------------------------------------------------------
-- RULE 3 — Financial immutability
-- Once a transaction is COMPLETED, its amount/fee can never be silently
-- edited — protects against fraud or accidental data corruption.
-- Reversals must go through the REVERSAL category, not an UPDATE.
-- ---------------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS trg_prevent_amount_change_after_completion$$
CREATE TRIGGER trg_prevent_amount_change_after_completion
BEFORE UPDATE ON Transactions
FOR EACH ROW
BEGIN
    IF OLD.status = 'COMPLETED'
       AND (NEW.amount <> OLD.amount OR NEW.fee <> OLD.fee)
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Amount/fee of a COMPLETED transaction cannot be modified. Use a REVERSAL transaction instead.';
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- RULE 4 — Audit trail on deletion
-- Any deletion of a transaction is automatically logged to System_Logs
-- before it happens, so there is always a record even if the row is gone.
-- ---------------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS trg_audit_transaction_delete$$
CREATE TRIGGER trg_audit_transaction_delete
BEFORE DELETE ON Transactions
FOR EACH ROW
BEGIN
    INSERT INTO System_Logs (related_sms_id, process_step, status, message)
    VALUES (OLD.source_sms_id, 'DELETE_TRANSACTION', 'SUCCESS',
            CONCAT('Transaction ', OLD.transaction_id, ' (amount ', OLD.amount, ') deleted at ', NOW()));
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- RULE 5 — Accuracy constraints already enforced at table level
-- (documented here for completeness, see database_setup.sql for definitions)
-- ---------------------------------------------------------------------
-- chk_tx_amount_positive     : Transactions.amount must be > 0
-- chk_tx_fee_nonnegative     : Transactions.fee must be >= 0
-- chk_users_phone_len        : Users.phone_number must be >= 6 characters
-- uq_users_phone             : phone_number must be unique per user
-- uq_tx_financial_id         : financial_tx_id must be unique (no duplicate MTN TxId)
-- uq_participant_role        : a user cannot hold the same role twice on one transaction
