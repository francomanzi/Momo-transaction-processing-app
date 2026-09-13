## Project Description

This project processes Mobile Money (MoMo) SMS transaction data delivered as XML.
The pipeline parses the raw XML, cleans and normalizes the records (amounts, dates,
phone numbers), categorizes each transaction, and loads the results into a relational
(SQLite) database. A lightweight frontend dashboard (with an optional FastAPI backend)
then visualizes the processed data — transaction volumes, categories, and trends —
so the team can analyze MoMo usage patterns.

**Goals for this phase:**
- Set up a shared team repository and workflow
- Define the high-level system architecture
- Organize the project structure
- Set up an Agile task board to track work

## Team Members

| Name | GitHub Username | Role |
|------|-----------------|------|
| [Divin Franco Manzi] | [@francomanzi] | [System Architecture/ Diagram|
| [Peace Maureen Umutesi] | [@umaureen] | [Scrum Lead ] |
| [Alda Gatakokabasinga]| [@alda_gatako] | [ Project Coordinator] |

## System Architecture

The high-level architecture diagram is included in the repo:
[`docs/architecture_diagram.png`](./docs/architecture_diagram.png)

Editable design source Draw.io: **https://drive.google.com/file/d/1ML9-3iCQms8ZGTU5O4qRLNqxpDAq4V4_/view?usp=sharing**

**Overview of components:**
- **Input:** Raw MoMo SMS XML data (`data/raw/momo.xml`)
- **XML Parser** (`etl/parse_xml.py`): reads the raw XML; valid records continue down the pipeline, invalid/unparseable records are written to **Dead Letter** (`logs/dead_letter/`), and all parsing activity is written to **ETL Logging** (`etl.log`)
- **Clean & Normalize** (`etl/clean_normalize.py`): standardizes amounts, dates, and phone numbers
- **Categorization** (`etl/categorize.py`): classifies each transaction (Transfer, Payment, Withdrawal, Airtime)
- **SQLite Database** (`data/db.sqlite3`): stores transactions, categories, amounts, and dates
- **FastAPI** (`api/app.py`): exposes `/transactions` and `/analytics` endpoints on top of the database
- **Web Dashboard** (`index.html`, `web/`): renders charts, tables, analytics, and transaction data
- **User / Analyst:** views and interacts with the dashboard in a browser

## Project Structure

See the repository directory layout below:

```
├── README.md
├── .env.example
├── requirements.txt
├── index.html
├── web/
│   ├── styles.css
│   ├── chart_handler.js
│   └── assets/
├── data/
│   ├── raw/            # git-ignored input XML
│   ├── processed/
│   ├── db.sqlite3
│   └── logs/
├── etl/
│   ├── config.py
│   ├── parse_xml.py
│   ├── clean_normalize.py
│   ├── categorize.py
│   ├── load_db.py
│   └── run.py
├── api/                # optional/bonus
│   ├── app.py
│   ├── db.py
│   └── schemas.py
├── scripts/
│   ├── run_etl.sh
│   ├── export_json.sh
│   └── serve_frontend.sh
└── tests/
    ├── test_parse_xml.py
    ├── test_clean_normalize.py
    └── test_categorize.py
```

## Scrum / Task Board

We are tracking work using **GitHub Projects**

**Board link: https://github.com/users/francomanzi/projects/3**

Board columns: `To Do` → `In Progress` → `Done`

Initial tasks include:
- Set up team GitHub repository & add collaborators
- Create high-level architecture diagram
- Draft ETL parsing logic for XML input
- Design SQLite schema for transactions
- Set up frontend dashboard skeleton
- Research MoMo SMS categorization rules

## Getting Started

```bash
# 1. Clone the repo
git clone https://github.com/francomanzi/Momo-transaction-processing-app.git
cd Momo-transaction-processing-app

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env

# 4. Run the ETL pipeline
python etl/run.py --xml data/raw/momo.xml

# 5. Serve the frontend
bash scripts/serve_frontend.sh
# then open http://localhost:8000
```# Momo-[Otransaction-proc[Oessing-appOB
