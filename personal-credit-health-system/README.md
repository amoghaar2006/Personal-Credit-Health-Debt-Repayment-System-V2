# Personal Credit Health and Debt Repayment Planning System

A MySQL-backed web application based on the supplied DBMS mini-project report and SQL script.

## Architecture

- **Frontend:** React 18, Vite, React Router, Recharts, Lucide React.
- **Backend:** Flask REST API, PyMySQL, Flask-CORS.
- **Database:** MySQL 8.0+.
- **Data flow:** React → Flask JSON API → MySQL. Dashboard metrics and record tables are queried from MySQL; the UI does not substitute local mock data.

## Project modules

- Overview dashboard
- Users
- Financial profiles
- Loans
- Repayments
- Repayment plans
- Plan payments

## Database notes

The six original domain tables are retained. The enhanced SQL adds:
- `app_account` for a future/optional account-authentication module; no login flow is exposed by this initial release.
- Indexes for common foreign-key, status and date lookups.
- `vw_loan_summary` and `vw_repayment_status`.
- The report's `GetLoanRepaymentDetails` procedure and `Calculate_Days_Late` trigger.
- A small idempotent seed set using values explicitly present in the report / original SQL.

The PDF does not contain the complete source dataset shown in several screenshots. Thus, the aggregate and 10-row outputs from the report cannot be recreated from the supplied SQL alone. No unseen dataset has been fabricated.

## Requirements

- MySQL Server 8.0+
- Python 3.10+
- Node.js 18+
- npm

## Setup (Windows PowerShell)

### 1. Create the database

Open a terminal in the project root. Import the enhanced schema (replace `root` with your MySQL user):

```powershell
mysql -u root -p < .\database\enhanced_database.sql
```

If PowerShell's input redirection behaves unexpectedly, use:

```powershell
Get-Content .\database\enhanced_database.sql | mysql -u root -p
```

### 2. Configure and start the backend

```powershell
cd .\backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
notepad .env
```

Set `DB_PASSWORD` in `.env`, then:

```powershell
python app.py
```

Backend: `http://127.0.0.1:5000`. Health check: `http://127.0.0.1:5000/api/health`.

### 3. Start the frontend (new terminal)

```powershell
cd .\frontend
npm install
npm run dev
```

Open `http://localhost:5173`.

## WSL / Linux setup

```bash
mysql -u root -p < database/enhanced_database.sql
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env and set DB_PASSWORD
python app.py
```

In another terminal:

```bash
cd frontend
npm install
npm run dev
```

## Tests

Backend validation and API-route contract tests:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
pytest -q
```

Database-backed routes require a running MySQL server and the imported schema.

Frontend browser smoke tests (from `frontend/`, after `npm install` and installing the browser once):

```powershell
npx playwright install chromium
npm run test:e2e
```

The browser tests start the Vite frontend and Flask backend. A working MySQL connection is required for the dashboard data request.

## API overview

- `GET /api/health`
- `GET /api/dashboard`
- `GET /api/<resource>?page=1&per_page=10&search=...`
- `GET /api/<resource>/<id>`
- `POST /api/<resource>`
- `PUT /api/<resource>/<id>`
- `DELETE /api/<resource>/<id>`

Resources: `users`, `financial-profiles`, `loans`, `repayments`, `repayment-plans`, `plan-payments`.

## Important limitations / next hardening steps

- The report does not provide the complete original data, so screenshot-identical aggregate outputs are not possible with only these files.
- This is a local development application. It does not yet implement login, role enforcement, CSRF protection, audit logs, password reset, or production deployment hardening. The `app_account` table is only a schema provision and must not be treated as active authentication.
- Deleting parent records may be rejected by MySQL foreign keys when child records exist; this protects referential integrity.
- `days_late` is calculated on repayment insertion. If an unpaid row remains open across days, a scheduled process or update trigger would be needed to refresh it later.
- The current API is designed for a trusted local environment. Do not expose it publicly without authentication, authorization, rate limiting, stricter CORS, TLS and security review.
