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

## Week 3 — REST API (current)

The MoMo SMS data is now exposed through a secure REST API built with plain
Python (`http.server`). It provides CRUD endpoints protected by Basic
Authentication, a JSON data set parsed from `modified_sms_v2.xml`, and a
data-structures & algorithms comparison (linear search vs dictionary lookup).

See **`docs/api_docs.md`** for the full API documentation and
**`docs/api_design_report.pdf`** for the PDF report.

| Assignment task | Where |
|---|---|
| 1. Parse XML → JSON | `dsa/parse_xml.py` (→ `data/modified_sms_v2.json`) |
| 2. CRUD endpoints (GET/POST/PUT/DELETE) | `api/app.py` |
| 3. Basic Auth + 401 on bad credentials | `api/app.py`, explained in `docs/api_docs.md` |
| 4. API documentation | `docs/api_docs.md` |
| 5. DSA: linear search vs dictionary lookup | `dsa/search_compare.py` (20+ records, results in `data/logs/dsa_results.txt`) |
| 6. Curl test evidence | `screenshots/` |
| PDF report | `docs/api_design_report.pdf` |

### Setup & run (Week 3)

```bash
# 1. Create the parsed data (only needed once)
python -m dsa.parse_xml        # -> data/modified_sms_v2.json (1,691 records)

# 2. Run the DSA comparison (optional)
python -m dsa.search_compare

# 3. Start the API (default http://127.0.0.1:8000)
python api/app.py

# 4. Test it with curl
curl -u admin:'Maureen123!' http://127.0.0.1:8000/transactions
curl -i -u admin:'Maureen123!' -X POST http://127.0.0.1:8000/transactions \
  -H 'Content-Type: application/json' -d '{"amount":500.0}'
```

API credentials default to **`admin` / `Maureen123!`** and can be overridden
with the `API_USER` and `API_PASS` environment variables.

> **Note:** `data/` is git-ignored, so `modified_sms_v2.xml` (1,691 MTN MoMo
> SMS records) and the parsed JSON are not committed. Copy the assignment file
> into `data/modified_sms_v2.xml` before running the parser.

## Team Members

| Name | GitHub Username | Role |
|------|-----------------|------|
| [Divin Franco Manzi] | [@francomanzi] | System Architecture / Diagram |
| [Peace Maureen Umutesi] | [@umaureen] | Scrum Lead |
| [Alda Gatakokabasinga] | [@alda_gatako] | Project Coordinator |


These match the commit authorship in Git history.

## AI USAGE

We used AI as a supporting tool throughout the development and documentation process. It helped us:

Come up with appropriate table names for the database design.
Define and refine transaction statuses such as SUCCESS, PENDING, and FAILED.
Define appropriate log levels such as INFO, WARNING, and ERROR.
Improve and organize our Markdown documentation, including the README, Data Dictionary, Google Drawing Specification, and Design Document.
Develop and refine the database constraints to ensure data integrity and consistency.
Create test scenarios for validating the constraints and checking that the database behaves as expected.

AI was used as a development and documentation assistant, while the final decisions, implementation, and validation were reviewed and made by the team.

## Database Design (6 Entities)

```
Users ────────────────┐
                      │ (M:N via Transaction_Participants)
Transactions ─────────┘
   ├─ Transaction_Categories
System_Logs ────────────┐
                       └─ Raw_SMS_Log
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
├── api/
│   └── app.py                   # Week-3 REST API (http.server + Basic Auth + CRUD)
├── dsa/
│   ├── parse_xml.py             # Week-3 XML → JSON parsing
│   └── search_compare.py        # Week-3 linear search vs dictionary lookup
├── screenshots/                 # Week-3 curl test evidence
├── etl/                        # Week-1 scaffolding (implementation in a later week)
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