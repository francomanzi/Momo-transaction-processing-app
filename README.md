# MoMo Transaction Processing App

## Project Description

This project designs and implements the **database foundation** for a Mobile
Money (MoMo) SMS transaction processing system. The source data is
`modified_sms_v2.xml` (1,693 MTN MoMo SMS messages). This repo (Week 2)
delivers:

- A **relational MySQL database** (`momo_sms_system`) — ERD, DDL, constraints,
  indexes and sample data built from the transactional SMS patterns
- **JSON data models** for every entity plus a documented SQL→JSON mapping for
  future API serialization
- **Security & accuracy rules** — least-privilege DB accounts, PII masking
  views, immutability/audit triggers
- **Tested CRUD and analytical queries** with documented outputs
- A **database design document** (ERD, rationale, data dictionary, sample
  queries)

The Week-1 scaffolding (`etl/`, `api/`, `tests/`) is reserved for later
weeks of the project.

## Team Members

| Name | GitHub Username | Role |
|------|-----------------|------|
| [Divin Franco Manzi] | [@francomanzi] | System Architecture / Diagram |
| [Peace Maureen Umutesi] | [@umaureen] | Scrum Lead |
| [Alda Gatakokabasinga] | [@alda_gatako] | Project Coordinator |

## Database Design (6 Entities)

```
Users ────────────────┐
                      │ (M:N)
Transactions ─────────┼─ Transaction_Participants (junction)
   │                   │
   ├─ Transaction_Categories
   └─ Raw_SMS_Log
System_Logs ─────────┘
```

| Entity | Purpose |
|---|---|
| `Users` | Customers, agents, merchants referenced by transactions |
| `Transaction_Categories` | Reference list of 10 MoMo transaction types |
| `Raw_SMS_Log` | Immutable staging table of every ingested SMS |
| `Transactions` | Core fact table: one confirmed/failed/reversed transaction |
| `Transaction_Participants` | Junction table resolving Users↔Transactions M:N with roles |
| `System_Logs` | ETL pipeline processing log for traceability |

- **ERD diagram:** `docs/erd_diagram.png`
- **Design rationale:** `docs/erd_design_rationale.md` (200–300 words)
- **Data dictionary:** `docs/data_dictionary.md`
- **Draw.io/Google Drawings spec:** `docs/erd_google_drawings_spec.md`

## Deliverables (Week 2 — database foundation)

| Assignment task | Where |
|---|---|
| 1. ERD with entities, PK/FK, cardinality, M:N junction | `docs/erd_diagram.png`, `docs/erd_design_rationale.md` |
| 2. MySQL schema: DDL + constraints + indexes + sample data | `database/database_setup.sql` |
| 2. CRUD testing with documented results | `database/crud_test_queries.sql`, `database/crud_test_results.md` |
| 3. JSON schemas + nested transaction example | `examples/json_schemas.json` |
| 3. SQL→JSON mapping documentation | `examples/sql_to_json_mapping.md` |
| 4. Database design document (PDF) | `docs/design_document.pdf` |

## Project Structure

```
├── README.md
├── database/
│   ├── database_setup.sql       # DDL + constraints + indexes + sample data (5+/table)
│   ├── security_rules.sql       # least-privilege users, masking view, triggers
│   ├── advanced_queries.sql     # analytical queries for the design document
│   ├── crud_test_queries.sql    # CRUD + constraint enforcement tests
│   └── *_results.md             # documented query outputs
├── docs/
│   ├── erd_diagram.png
│   ├── erd_design_rationale.md
│   ├── erd_google_drawings_spec.md
│   ├── data_dictionary.md
│   └── design_document.pdf
├── examples/
│   ├── json_schemas.json        # JSON Schema for every entity + complex transaction
│   └── sql_to_json_mapping.md   # SQL→JSON serialization guide
├── etl/                        # Week-1 scaffolding (implementation in a later week)
├── api/                        # Week-1 scaffolding
├── tests/                      # Week-1 scaffolding
├── scripts/
├── web/
└── requirements.txt            # reserved for later weeks
```

## Getting Started

### 1. Prerequisites

- MySQL 8.0+ (developed and verified on MySQL 26.7)

### 2. Set up the database

```bash
mysql -u root -p < database/database_setup.sql   # creates momo_sms_system + sample data
mysql -u root -p < database/security_rules.sql   # app users, masking view, triggers
```

### 3. Explore the data

```bash
mysql -u root -p momo_sms_system < database/advanced_queries.sql
mysql -u root -p momo_sms_system < database/crud_test_queries.sql
```

### 4. Security accounts created

| User | Password (dev only) | Privileges |
|---|---|---|
| `momo_readonly` | `Maureen123!` | SELECT on all tables + masking view |
| `momo_etl` | `Maureen123!` | INSERT/UPDATE/SELECT (no DELETE) |
| `momo_admin` | `Maureen123!` | Full control |

> **Note:** `security_rules.sql` starts by recreating these users for
> idempotence; if a user already exists in your server it is dropped first
> only when it is owned by this script's marker comment.

## Scrum / Task Board

Tracked on **GitHub Projects**

**Board link: https://github.com/users/francomanzi/projects/3**

Board columns: `To Do` → `In Progress` → `Done`