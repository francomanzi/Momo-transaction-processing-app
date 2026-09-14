# SQL → JSON Mapping — MoMo SMS Data Processing System

This document explains how the relational schema in `database/database_setup.sql`
is serialized into the JSON shapes in `examples/json_schemas.json`.

## 1. Direct table → object mapping

Most tables map 1:1 to a flat JSON object with the same column names:

| SQL Table | JSON Schema | Notes |
|---|---|---|
| `Users` | `User` | `user_category` ENUM → JSON string enum |
| `Transaction_Categories` | `TransactionCategory` | `is_debit` TINYINT(1)/BOOLEAN → JSON boolean |
| `Raw_SMS_Log` | `RawSMSLog` | `is_parsed` → JSON boolean |
| `System_Logs` | `SystemLog` | `related_sms_id` nullable FK → JSON `null` when absent |

## 2. Denormalizing on read: Transactions

The `Transactions` table itself only holds `category_id` and `source_sms_id` as
foreign keys. When serialized for an API response, we **denormalize** by
resolving those FKs into nested objects:

- `category_id` (INT FK) → full nested `category` object (id, code, name, is_debit)
- `source_sms_id` (INT FK, nullable) → full nested `source_sms` object, or omitted/`null` in list views to keep payloads light

This is a **read-time join**, not a schema change — the underlying SQL stays
normalized (3NF); only the API response layer flattens the joins into nested
JSON for client convenience. The mapping SQL for the full nested transaction is:

```sql
SELECT t.*, tc.category_code, tc.category_name, tc.is_debit
FROM Transactions t
JOIN Transaction_Categories tc ON tc.category_id = t.category_id
WHERE t.transaction_id = ?;
```
followed by a second query against `Transaction_Participants JOIN Users` to
build the `participants` array (see below).

## 3. Resolving the M:N junction table into a nested array

This is the most important mapping in the system. The relational M:N between
`Users` and `Transactions` is resolved with the `Transaction_Participants`
junction table:

```sql
SELECT tp.participant_id, tp.participant_role, u.user_id, u.full_name, u.phone_number, u.user_category
FROM Transaction_Participants tp
JOIN Users u ON u.user_id = tp.user_id
WHERE tp.transaction_id = ?;
```

In JSON, this relational join becomes a **nested array of `Participant`
objects** on the parent `Transaction`:

```json
"participants": [
  { "participant_id": 8, "participant_role": "SENDER", "user": { "user_id": 1, "full_name": "..." } },
  { "participant_id": 9, "participant_role": "AGENT",  "user": { "user_id": 7, "full_name": "..." } }
]
```

This is why `complex_transaction_full_example` in `json_schemas.json` can show
a 3-party agent withdrawal (SENDER + AGENT) as a single JSON object even
though it comes from 3 separate SQL tables (`Transactions`,
`Transaction_Participants` ×2, `Users` ×2) — the junction table's rows become
array elements, and each element's FK to `Users` becomes a nested object
rather than a bare `user_id`.

## 4. Two serialization depths: detail vs. list

The schema defines two response shapes for the same underlying data,
matching common API design practice:

- **Detail view** (`api_response_get_transaction_by_id`) — full nesting:
  category object, all participants each with a full user object, optional
  source SMS and processing logs. Used for `GET /transactions/{id}`.
- **List view** (`api_response_list_transactions_by_user`) — flattened,
  lightweight: only `category_code` (string, not full object) and a single
  `counterparty` field (the *other* participant relative to the requested
  user) rather than the full `participants` array. Used for
  `GET /users/{id}/transactions`, where N+1 nested objects per row would
  bloat the payload.

Both are derived from the same tables; the difference is purely at the
API/serialization layer, not the database layer.

## 5. Type mapping reference

| MySQL type | JSON type |
|---|---|
| `INT` / `INT AUTO_INCREMENT` | `integer` |
| `VARCHAR(n)` | `string` (with `maxLength: n`) |
| `TEXT` | `string` |
| `DECIMAL(p,s)` | `number` |
| `DATETIME` | `string`, `format: date-time` (ISO 8601) |
| `BOOLEAN` / `TINYINT(1)` | `boolean` |
| `ENUM(...)` | `string`, `enum: [...]` |
| Nullable column | JSON type unioned with `null`, e.g. `["string", "null"]` |
