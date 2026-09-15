-- =====================================================================
-- CRUD Test Queries — MoMo SMS Data Processing System
-- Run against momo_sms_system after database_setup.sql
-- Results of running the equivalent logic are documented in
-- crud_test_results.md (executed via SQLite in the dev sandbox,
-- since no live MySQL server was available; syntax below is MySQL).
-- =====================================================================

-- ---------- CREATE ----------
INSERT INTO Users (full_name, phone_number, user_category)
VALUES ('David Mugisha', '250788123456', 'CUSTOMER');

INSERT INTO Transactions (category_id, amount, fee, balance_after, transaction_date, status)
VALUES ((SELECT category_id FROM Transaction_Categories WHERE category_code='BUNDLE_PURCHASE'),
        1500.00, 0.00, 5000.00, '2025-02-01 10:00:00', 'COMPLETED');
SET @test_tx_id = LAST_INSERT_ID();

INSERT INTO Transaction_Participants (transaction_id, user_id, participant_role)
VALUES (@test_tx_id,
        (SELECT user_id FROM Users WHERE full_name='David Mugisha'), 'SENDER');

-- ---------- READ ----------
SELECT user_id, full_name, phone_number, user_category FROM Users ORDER BY user_id;

SELECT t.transaction_id, tc.category_name, t.amount, t.fee, t.status,
       GROUP_CONCAT(u.full_name, ':', tp.participant_role SEPARATOR ', ') AS participants
FROM Transactions t
JOIN Transaction_Categories tc ON tc.category_id = t.category_id
LEFT JOIN Transaction_Participants tp ON tp.transaction_id = t.transaction_id
LEFT JOIN Users u ON u.user_id = tp.user_id
GROUP BY t.transaction_id
ORDER BY t.transaction_id;

-- ---------- UPDATE ----------
UPDATE Users SET phone_number = '250788654321' WHERE full_name = 'David Mugisha';

SELECT user_id, full_name, phone_number FROM Users WHERE full_name = 'David Mugisha';

-- ---------- DELETE ----------
-- Only the test transaction created above is removed (by its captured id) —
-- never the real sample data. ON DELETE CASCADE on Transaction_Participants
-- removes the orphaned link automatically.
DELETE FROM Transactions WHERE transaction_id = @test_tx_id;

SELECT COUNT(*) AS remaining_orphan_participants
FROM Transaction_Participants
WHERE transaction_id NOT IN (SELECT transaction_id FROM Transactions);

-- ---------- CONSTRAINT ENFORCEMENT TESTS (each of these should fail/reject) ----------
INSERT INTO Transactions (category_id, amount, fee, transaction_date)
VALUES (1, -500.00, 0.00, '2025-02-01 10:00:00');            -- violates chk_tx_amount_positive
-- This test reuses Jane Smith's real phone number under a fake name
-- ("Fake Jane"), confirming that uq_users_phone blocks duplicates by
-- phone number specifically, not just by matching name.
INSERT INTO Users (full_name, phone_number)
VALUES ('Fake Jane', '250789013000');                        -- violates uq_users_phone

INSERT INTO Transaction_Participants (transaction_id, user_id, participant_role)
VALUES (1, 1, 'BYSTANDER');                                  -- violates ENUM/participant_role constraint
