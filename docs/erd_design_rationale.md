# ERD Design Rationale — MoMo SMS Data Processing System

## Design Decisions

**Six entities, not four.** The assignment requires Transactions, Users, Transaction_Categories, and System_Logs. We added two more because the raw XML data demanded it: **Raw_SMS_Log** and the junction table **Transaction_Participants**. Analysis of `modified_sms_v2.xml` (1,693 messages) showed roughly 60 are non-transactional (OTPs), so a raw SMS cannot always produce a transaction — this justified a separate `Raw_SMS_Log` table with an `is_parsed` flag, related to `Transactions` as 1:0..1 rather than force-fitting OTPs into the transaction table with null financial fields.

**Why Transaction_Categories is a real table, not an ENUM column.** Ten distinct transaction patterns emerged from the SMS bodies (incoming money, P2P transfer, merchant/code-holder payment, airtime, bundle purchase, bank deposit, agent withdrawal, linked-bank transfer, reversal, failed transaction). Storing this as a lookup table with a `category_code` and `is_debit` flag makes the categorization logic data-driven and lets new categories be added without a schema change or code redeploy.

**Why the M:N relationship is Users↔Transactions via roles, not a padded one.** Several transaction types in the data involve three parties, not two — agent withdrawals show a customer, an agent, and the transaction itself. Modeling `sender_id` / `receiver_id` as two FK columns cannot represent a third participant and breaks when a transaction has only one party (e.g., a bundle purchase debited from self). Instead, `Transaction_Participants(transaction_id, user_id, participant_role)` resolves the natural M:N: one user appears in many transactions, and one transaction involves multiple users in distinct roles (SENDER, RECEIVER, AGENT), matching real-world data rather than an artificial two-column shortcut.

**System_Logs** tracks data-processing events (parse success/failure per SMS) rather than application logs, keeping observability inside the database layer as the assignment specifies, linked back to the source SMS record for traceability.
