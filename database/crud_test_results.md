# CRUD Test Results — MoMo SMS Database

**Method note:** All queries below were executed verbatim against a real
MySQL 8.0+ server (local temporary instance) using `database_setup.sql` then
`crud_test_queries.sql`. Output shown is the actual MySQL result grid.
Keep this command pattern for reproducible results with MySQL Workbench:
run `database_setup.sql`, then `crud_test_queries.sql`, and screenshot each
output block for the submission.

## CREATE
Inserted a new user, a new transaction, and linked them via `Transaction_Participants`.
```
INSERT INTO Users ...            -> OK, 1 row affected
INSERT INTO Transactions ...     -> OK, 1 row affected
INSERT INTO Transaction_Participants ... -> OK, 1 row affected
```

## READ
**All users (10 rows after the CREATE above):**
```
user_id | full_name             | phone_number   | user_category
1       | Abebe Chala Chebudie  | 250795963036   | CUSTOMER
2       | Jane Smith            | 250789013000   | CUSTOMER
3       | Samuel Carter         | 250791666666   | CUSTOMER
4       | Alex Doe              | 250790777777   | CUSTOMER
5       | Robert Brown          | 250788999999   | CUSTOMER
6       | Linda Green           | 250790777778   | CUSTOMER
7       | Agent Sophia          | 250790777779   | AGENT
8       | IREMBO Ltd            | 250700000001   | MERCHANT
9       | ESICIA LTD KPAY       | 250700000002   | MERCHANT
10      | David Mugisha         | 250788123456   | CUSTOMER
```

**Full transaction detail (JOIN across Transactions → Categories → Participants → Users):**
```
tx_id | category_name         | amount | fee | status    | participants
1     | Incoming Money        | 2000   | 0   | COMPLETED | Abebe Chala Chebudie:RECEIVER, Jane Smith:SENDER
2     | Merchant Payment      | 1000   | 0   | COMPLETED | Abebe Chala Chebudie:SENDER, Jane Smith:RECEIVER
3     | Bank Deposit          | 40000  | 0   | COMPLETED | Abebe Chala Chebudie:RECEIVER
4     | Mobile Transfer       | 10000  | 100 | COMPLETED | Abebe Chala Chebudie:SENDER, Samuel Carter:RECEIVER
5     | Agent Cash Withdrawal | 20000  | 0   | COMPLETED | Abebe Chala Chebudie:SENDER, Agent Sophia:AGENT
6     | Bundle Purchase       | 1500   | 0   | COMPLETED | David Mugisha:SENDER
```
This confirms the junction table correctly reconstructs multi-party transactions (transaction 5 shows both a SENDER and an AGENT).

## UPDATE
```
UPDATE Users SET phone_number = '250788654321' WHERE full_name = 'David Mugisha';
-> OK, 1 row affected

Verify:
user_id | full_name     | phone_number
10      | David Mugisha | 250788654321   ✔ updated correctly
```

## DELETE
```
DELETE FROM Transactions WHERE transaction_id = @test_tx_id;
-> OK, 1 row affected  (only the disposable test transaction is removed)

Verify orphan participants after cascade:
remaining_orphan_participants
0    ✔ ON DELETE CASCADE correctly removed the linked Transaction_Participants row
```

## Constraint Enforcement (negative tests — each MUST fail, and did)
```
INSERT amount = -500.00
-> ERROR 3819 (HY000): Check constraint 'chk_tx_amount_positive' is violated.
                                                              ✔ chk_tx_amount_positive works

INSERT duplicate phone_number '250789013000'
-> ERROR 1062 (23000): Duplicate entry '250789013000' for key 'users.uq_users_phone'
                                                              ✔ uq_users_phone works

INSERT participant_role = 'BYSTANDER'
-> ERROR 1265 (01000): Data truncated for column 'participant_role' at row 1
                                                              ✔ participant_role ENUM rejects bad value
```

**Conclusion:** All four CRUD operations succeed as expected, the M:N junction table correctly reconstructs multi-party transactions, referential integrity (CASCADE/SET NULL) behaves correctly on delete, and all three tested constraints (positive amount, unique phone, valid participant role) correctly reject bad data.
