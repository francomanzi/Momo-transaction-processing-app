# Database Data Dictionary — `momo_sms_system`

Engine: MySQL 8.0+ · Character set: `utf8mb4` / `utf8mb4_unicode_ci`

This data dictionary documents every table and column in the MoMo SMS
database. It mirrors the `COMMENT` clauses in `database/database_setup.sql`
and is the authoritative reference for the design document PDF.

## Conventions

| Marker | Meaning |
|---|---|
| `PK`  | Primary key (auto increment where noted) |
| `FK`  | Foreign key referencing the table shown in [] |
| `UQ`  | UNIQUE constraint |
| `CK`  | CHECK constraint |
| `NN`  | NOT NULL |
| `DEF` | Default value |

---

## 1. Users

Customers, agents and merchants referenced by MoMo transactions. Identities
are extracted from the SMS text.

| Column | Type | Null | Constraints | Description |
|---|---|---|---|---|
| user_id | INT | NN | PK, AUTO_INCREMENT | Unique ID for a person/agent/merchant found in the SMS text |
| full_name | VARCHAR(100) | NN | | Name as it appears in the SMS body |
| phone_number | VARCHAR(15) | NN | UQ (`uq_users_phone`), CK `chk_users_phone_len` (length >= 6) | MSISDN, may be partially masked in source data |
| user_category | ENUM('CUSTOMER','AGENT','MERCHANT') | NN | DEF 'CUSTOMER' | Role this identity plays in the MoMo ecosystem |
| national_id_masked | VARCHAR(20) | NULL | | Masked national ID / account ref when present in SMS |
| created_at | DATETIME | NN | DEF CURRENT_TIMESTAMP | When this identity was first seen |

Indexes: `idx_users_phone` on `phone_number` (in addition to UNIQUE).

---

## 2. Transaction_Categories

Reference list of MoMo transaction types (payment, transfer, deposit, etc.).
Keeps categorization logic data-driven instead of hardcoded.

| Column | Type | Null | Constraints | Description |
|---|---|---|---|---|
| category_id | INT | NN | PK, AUTO_INCREMENT | Unique ID for a transaction category |
| category_code | VARCHAR(30) | NN | UQ (`uq_category_code`) | Machine-readable code used by the ETL parser |
| category_name | VARCHAR(60) | NN | | Human-readable label |
| description | VARCHAR(255) | NULL | | What kind of SMS pattern maps to this category |
| is_debit | BOOLEAN | NN | DEF TRUE | TRUE if this category reduces account balance |

---

## 3. Raw_SMS_Log

Immutable staging table holding every ingested SMS prior to parsing. Not
every row becomes a transaction (e.g. OTP messages), hence the `is_parsed`
flag.

| Column | Type | Null | Constraints | Description |
|---|---|---|---|---|
| sms_id | INT | NN | PK, AUTO_INCREMENT | Unique ID for a raw SMS record |
| sender_address | VARCHAR(30) | NN | | SMS sender address, e.g. M-Money |
| raw_body | TEXT | NN | | Full untouched SMS body text |
| sms_date | DATETIME | NN | | Timestamp the SMS was received (from readable_date) |
| is_parsed | BOOLEAN | NN | DEF FALSE | TRUE once ETL has successfully extracted a transaction |

---

## 4. Transactions

Core fact table of confirmed/failed/reversed MoMo transactions.

| Column | Type | Null | Constraints | Description |
|---|---|---|---|---|
| transaction_id | INT | NN | PK, AUTO_INCREMENT | Unique ID for a transaction |
| category_id | INT | NN | FK → Transaction_Categories (`fk_tx_category`, ON DELETE RESTRICT) | Category the transaction belongs to |
| financial_tx_id | VARCHAR(30) | NULL | UQ (`uq_tx_financial_id`) | MTN "Financial Transaction Id" / TxId extracted from SMS |
| external_tx_id | VARCHAR(30) | NULL | | External transaction id, when present (e.g. data bundle purchases) |
| amount | DECIMAL(12,2) | NN | CK `chk_tx_amount_positive` (amount > 0) | Transaction amount in RWF |
| fee | DECIMAL(10,2) | NN | DEF 0.00, CK `chk_tx_fee_nonnegative` (fee >= 0) | Fee charged for the transaction in RWF |
| balance_after | DECIMAL(12,2) | NULL | | Account balance immediately after the transaction |
| transaction_date | DATETIME | NN | | Date/time the transaction was completed |
| status | ENUM('COMPLETED','FAILED','REVERSED') | NN | DEF 'COMPLETED' | Final state of the transaction |
| source_sms_id | INT | NULL | FK → Raw_SMS_Log (`fk_tx_sms`, ON DELETE SET NULL) | Traceability back to the raw message |

Indexes: `idx_tx_date`, `idx_tx_category`, `idx_tx_status`.

---

## 5. Transaction_Participants

Junction table resolving the M:N relationship between Users and
Transactions. A transaction can involve multiple users in different roles
(sender, receiver, agent); a user appears across many transactions.

| Column | Type | Null | Constraints | Description |
|---|---|---|---|---|
| participant_id | INT | NN | PK, AUTO_INCREMENT | Unique ID for a participation record |
| transaction_id | INT | NN | FK → Transactions (`fk_participant_tx`, ON DELETE CASCADE) | Transaction this participation belongs to |
| user_id | INT | NN | FK → Users (`fk_participant_user`, ON DELETE RESTRICT) | User taking part in the transaction |
| participant_role | ENUM('SENDER','RECEIVER','AGENT') | NN | UQ `uq_participant_role` (transaction_id, user_id, participant_role) | Role this user plays in the transaction |

Indexes: `idx_participants_user`, `idx_participants_tx`.

---

## 6. System_Logs

ETL pipeline processing log for traceability and debugging — one row per
processing step/outcome.

| Column | Type | Null | Constraints | Description |
|---|---|---|---|---|
| log_id | INT | NN | PK, AUTO_INCREMENT | Unique ID for a log entry |
| related_sms_id | INT | NULL | FK → Raw_SMS_Log (`fk_log_sms`, ON DELETE SET NULL) | The SMS record being processed |
| process_step | VARCHAR(40) | NN | | ETL stage, e.g. PARSE, CATEGORIZE, LOAD |
| status | ENUM('SUCCESS','FAILED') | NN | | Outcome of this processing step |
| message | VARCHAR(255) | NULL | | Detail message or error text |
| logged_at | DATETIME | NN | DEF CURRENT_TIMESTAMP | When this log entry was written |

Indexes: `idx_logs_status`, `idx_logs_sms`.

---

## Relationships

```
Users ────────────────┐
                      │ (M:N, resolved by Transaction_Participants)
Transactions ─────────┘
   │                     ┌──────────────────────────┐
   ├─ Transaction_Categories   (M:1 — each transaction has one category)
   └─ Raw_SMS_Log              (1:1 — each transaction traces to one raw SMS)
System_Logs ────────────┘      (1:1 opt — each log row may reference one SMS)
```

| Source | Target | Cardinality | Junction |
|---|---|---|---|
| Users | Transactions | M:N | Transaction_Participants |
| Transactions | Transaction_Categories | M:1 | — |
| Transactions | Raw_SMS_Log | 1:1 (opt) | — |
| System_Logs | Raw_SMS_Log | M:1 (opt) | — |

## Sample Data Size

| Table | Rows in `database_setup.sql` |
|---|---|
| Users | 9 |
| Transaction_Categories | 10 |
| Raw_SMS_Log | 6 |
| Transactions | 5 |
| Transaction_Participants | 8 |
| System_Logs | 6 |