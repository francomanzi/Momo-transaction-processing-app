# ERD — Manual Build Spec (Google Drawings backup)

Use this only if you want to rebuild/tweak the ERD yourself instead of using `erd_diagram.png`.
Layout: 6 rectangles (entities), left-to-right in 3 columns as below.

```
Column 1 (top)       Column 2 (top)              Column 3
USERS                                             TRANSACTION_PARTICIPANTS
Column 1 (mid)        Column 2 (mid)
TRANSACTION_          TRANSACTIONS
CATEGORIES
Column 1 (bottom)
RAW_SMS_LOG  ---(1:M)---  SYSTEM_LOGS
```

## Boxes (header bar + rows, PK bold+underlined, FK bold)

**USERS**
- PK user_id — INT
- full_name — VARCHAR(100)
- phone_number — VARCHAR(15)
- user_category — ENUM('CUSTOMER','AGENT','MERCHANT')
- national_id_masked — VARCHAR(20)
- created_at — DATETIME

**TRANSACTION_CATEGORIES**
- PK category_id — INT
- category_code — VARCHAR(30)
- category_name — VARCHAR(60)
- description — VARCHAR(255)
- is_debit — BOOLEAN

**TRANSACTIONS**
- PK transaction_id — INT
- FK category_id — INT
- financial_tx_id — VARCHAR(30)
- external_tx_id — VARCHAR(30)
- amount — DECIMAL(12,2)
- fee — DECIMAL(10,2)
- balance_after — DECIMAL(12,2)
- transaction_date — DATETIME
- status — ENUM('COMPLETED','FAILED','REVERSED')
- FK source_sms_id — INT

**TRANSACTION_PARTICIPANTS** (junction table)
- PK participant_id — INT
- FK transaction_id — INT
- FK user_id — INT
- participant_role — ENUM('SENDER','RECEIVER','AGENT')

**RAW_SMS_LOG**
- PK sms_id — INT
- sender_address — VARCHAR(30)
- raw_body — TEXT
- sms_date — DATETIME
- is_parsed — BOOLEAN

**SYSTEM_LOGS**
- PK log_id — INT
- FK related_sms_id — INT
- process_step — VARCHAR(40)
- status — ENUM('SUCCESS','FAILED')
- message — VARCHAR(255)
- logged_at — DATETIME

## Connectors (use crow's-foot line ends in Google Drawings' shape library)

| From | To | Cardinality | Notes |
|---|---|---|---|
| TRANSACTION_CATEGORIES | TRANSACTIONS | 1 : M | one category, many transactions |
| TRANSACTIONS | TRANSACTION_PARTICIPANTS | 1 : M | one transaction, many participant rows |
| USERS | TRANSACTION_PARTICIPANTS | 1 : M | one user, many participant rows → together these two 1:M lines resolve the Users↔Transactions M:N |
| RAW_SMS_LOG | TRANSACTIONS | 1 : 0..1 | not every SMS becomes a transaction (e.g. OTPs) |
| RAW_SMS_LOG | SYSTEM_LOGS | 1 : M | one SMS can log multiple ETL steps/errors |

Color suggestion (optional, matches generated PNG): dark navy header bars for lookup/log tables, deep blue for TRANSACTIONS, purple for the junction table — makes the M:N resolution visually obvious at a glance.
