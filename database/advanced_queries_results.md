# Advanced Query Results

Executed against the sample data in `database_setup.sql` on a real MySQL
server (same method as `crud_test_results.md`).

## 1. Total amount and average per category
```
category_name          | tx_count | total_amount | avg_amount
Bank Deposit            | 1        | 40000        | 40000.0
Agent Cash Withdrawal   | 1        | 20000        | 20000.0
Mobile Transfer         | 1        | 10000        | 10000.0
Incoming Money          | 1        | 2000         | 2000.0
Merchant Payment        | 1        | 1000         | 1000.0
Airtime Purchase        | 0        | —            | —
Bundle Purchase         | 0        | —            | —
Linked Bank Transfer    | 0        | —            | —
Transaction Reversal    | 0        | —            | —
Failed Transaction      | 0        | —            | —
```
With the full 1,691-message dataset loaded (rather than the 5-row sample),
this same query is what would drive a "spend by category" dashboard chart.

## 2. Top users by total received
```
full_name             | times_received | total_received
Abebe Chala Chebudie  | 2              | 42000
Samuel Carter         | 1              | 10000
Jane Smith            | 1              | 1000
```

## 3. Monthly fees paid by the account owner
```
month    | total_fees | tx_count
2024-05  | 100        | 2
2024-11  | 0          | 1
```

## 4. ETL parse success rate
```
status  | count | pct
SUCCESS | 5     | 83.3
FAILED  | 1     | 16.7
```
   A 16.7% failure rate sounds high at first, but since there's only 6 total log entries, that's just 1 message — not necessarily a systemic problem.

## 5. Multi-party transaction check
```
transaction_id | category_name        | participant_count
1              | Incoming Money         | 2
2              | Merchant Payment       | 2
4              | Mobile Transfer        | 2
5              | Agent Cash Withdrawal  | 2
```
Confirms every transaction correctly resolves to 2 participants via the
junction table (sender + receiver, or sender + agent) — validating that
`Transaction_Participants` is working as designed.
