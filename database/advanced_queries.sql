-- =====================================================================
-- Advanced Sample Queries — MoMo SMS Data Processing System
-- Demonstrates analytical use of the schema beyond basic CRUD.
-- Run after database_setup.sql. Results documented in
-- advanced_queries_results.md.
-- =====================================================================

-- 1. Total amount moved and average transaction size per category
SELECT tc.category_name,
       COUNT(t.transaction_id) AS tx_count,
       SUM(t.amount) AS total_amount,
       ROUND(AVG(t.amount), 2) AS avg_amount
FROM Transaction_Categories tc
LEFT JOIN Transactions t ON t.category_id = tc.category_id
GROUP BY tc.category_id
ORDER BY total_amount DESC;

-- 2. Top 5 users by total money received (RECEIVER participation)
SELECT u.full_name,
       COUNT(*) AS times_received,
       SUM(t.amount) AS total_received
FROM Transaction_Participants tp
JOIN Users u ON u.user_id = tp.user_id
JOIN Transactions t ON t.transaction_id = tp.transaction_id
WHERE tp.participant_role = 'RECEIVER'
GROUP BY u.user_id
ORDER BY total_received DESC
LIMIT 5;

-- 3. Total fees paid by the account owner, by month
SELECT DATE_FORMAT(t.transaction_date, '%Y-%m') AS month,
       SUM(t.fee) AS total_fees,
       COUNT(*) AS tx_count
FROM Transactions t
JOIN Transaction_Participants tp ON tp.transaction_id = t.transaction_id
JOIN Users u ON u.user_id = tp.user_id
WHERE u.full_name = 'Abebe Chala Chebudie' AND tp.participant_role = 'SENDER'
GROUP BY month
ORDER BY month;

-- 4. ETL health check: parse success rate from System_Logs
SELECT status,
       COUNT(*) AS count,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM System_Logs), 1) AS pct
FROM System_Logs
GROUP BY status;

-- 5. Transactions with 2+ participants (multi-party check, validates the junction table)
SELECT t.transaction_id, tc.category_name, COUNT(tp.participant_id) AS participant_count
FROM Transactions t
JOIN Transaction_Categories tc ON tc.category_id = t.category_id
JOIN Transaction_Participants tp ON tp.transaction_id = t.transaction_id
GROUP BY t.transaction_id
HAVING participant_count >= 2
ORDER BY participant_count DESC;   -- Note: transaction_id 3 doesn't appear here because it has only 1
   -- participant. It's a Bank Deposit, where money enters from outside
   -- the system (a bank), so there's no second MoMo user to record as SENDER.

-- Note: transaction_id 3 is excluded here because it only has 1 participant.
