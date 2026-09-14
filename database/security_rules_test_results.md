# Security & Accuracy Rules — Test Results

**Method note:** All rules below were verified against a real MySQL 8.0+
server (local temporary instance). `GRANT`/`CREATE USER`, the masking view,
and both triggers were executed and tested for real, not simulated.

## Rule 1 — Least-privilege accounts (`momo_readonly`, `momo_etl`, `momo_admin`)
Three users created with minimal privileges. Verified live with conflicting
attempts:
```
SELECT * FROM Users;                          -- as momo_readonly
-> ERROR 1142 (42000): SELECT command denied ... for table 'users'
   ✔ readonly account cannot read raw PII

DELETE FROM Transactions WHERE transaction_id = 99999;   -- as momo_etl
-> ERROR 1142 (42000): DELETE command denied to user 'momo_etl'@'localhost'
   ✔ ETL account cannot ever delete financial records

Confirm grants:
SHOW GRANTS FOR 'momo_readonly'@'%';   -- SELECT only, and never on Users
SHOW GRANTS FOR 'momo_etl'@'%';        -- SELECT, INSERT, UPDATE
SHOW GRANTS FOR 'momo_admin'@'%';      -- ALL on momo_sms_system.*
```

## Rule 2 — PII masking view (`View_Users_Masked`)
```
user_id | full_name             | phone_number_masked | user_category | created_at
1       | Abebe Chala Chebudie  | *******3036          | CUSTOMER  | ...
2       | Jane Smith            | *******3000          | CUSTOMER  | ...
3       | Samuel Carter         | *******6666          | CUSTOMER  | ...
4       | Alex Doe              | *******7777          | CUSTOMER  | ...
5       | Robert Brown          | *******9999          | CUSTOMER  | ...
```
✔ Full phone numbers are never exposed through this view — only the last
4 digits. The `momo_readonly` account is granted access to this view and
not granted `SELECT` on the base `Users` table (verified above).

## Rule 3 — Financial immutability trigger
```
Testing an illegal amount edit on transaction_id=1 (status=COMPLETED)...
BLOCKED as expected: Amount/fee of a COMPLETED transaction cannot be
modified. Use a REVERSAL transaction instead.
```
✔ The trigger correctly rejects any attempt to silently change the amount
or fee of a transaction that is already `COMPLETED`, preventing both
accidental data corruption and post-hoc fraud on financial records.

## Rule 4 — Audit trail on delete
```
Inserted disposable transaction_id=7 to test deletion audit
Deleted. Checking System_Logs for the auto-generated audit row:
log_id | process_step        | status  | message
7      | DELETE_TRANSACTION  | SUCCESS | Transaction 7 (amount 500) deleted
```
✔ Deleting a transaction automatically writes an audit entry to
`System_Logs` *before* the row disappears, so there is always a trace of
what was deleted, when, and for how much — even without a separate audit
table.

## Rule 5 — Accuracy constraints (recap, already proven in `crud_test_results.md`)
`chk_tx_amount_positive`, `chk_tx_fee_nonnegative`, `chk_users_phone_len`,
`uq_users_phone`, `uq_tx_financial_id`, and `uq_participant_role` were all
exercised and confirmed working during the CRUD test pass.
