import os
import re
from datetime import date, datetime
from decimal import Decimal
from functools import wraps

import pymysql
from pymysql.cursors import DictCursor
from flask import Flask, jsonify, request
from werkzeug.exceptions import HTTPException
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

RESOURCE_CONFIG = {
    "users": {
        "table": "`user`", "pk": "user_id",
        "columns": ["user_id"],
        "required": ["user_id"],
        "search": ["user_id"],
    },
    "financial-profiles": {
        "table": "financial_profile", "pk": "profile_id",
        "columns": ["user_id", "monthly_income_usd", "monthly_expenses_usd",
                    "savings_usd", "has_loan", "debt_to_income_ratio",
                    "credit_score", "record_date"],
        "required": ["user_id", "monthly_income_usd", "monthly_expenses_usd",
                     "savings_usd", "has_loan", "debt_to_income_ratio",
                     "credit_score", "record_date"],
        "search": ["user_id", "has_loan"],
    },
    "loans": {
        "table": "loan", "pk": "loan_id",
        "columns": ["loan_id", "user_id", "loan_type", "loan_amount_usd",
                    "loan_term_months", "monthly_emi_usd", "loan_interest_rate_pct"],
        "required": ["loan_id", "user_id", "loan_type", "loan_amount_usd",
                     "loan_term_months", "monthly_emi_usd", "loan_interest_rate_pct"],
        "search": ["loan_id", "user_id", "loan_type"],
    },
    "repayments": {
        "table": "repayment", "pk": "payment_id",
        "columns": ["payment_id", "loan_id", "installment_number", "due_date",
                    "payment_date", "amount_due_usd", "amount_paid_usd",
                    "payment_status", "remaining_balance_usd"],
        "required": ["payment_id", "loan_id", "installment_number", "due_date",
                     "amount_due_usd", "payment_status", "remaining_balance_usd"],
        "search": ["payment_id", "loan_id", "payment_status"],
    },
    "repayment-plans": {
        "table": "repayment_plan", "pk": "plan_id",
        "columns": ["user_id", "plan_date", "total_months",
                    "monthly_available_amount", "risk_level", "plan_status"],
        "required": ["user_id", "plan_date", "total_months",
                     "monthly_available_amount", "risk_level"],
        "search": ["user_id", "risk_level", "plan_status"],
    },
    "plan-payments": {
        "table": "plan_payment", "pk": "plan_payment_id",
        "columns": ["plan_id", "loan_id", "due_month",
                    "planned_amount_usd", "priority_order"],
        "required": ["plan_id", "loan_id", "due_month",
                     "planned_amount_usd", "priority_order"],
        "search": ["loan_id", "due_month"],
    },
}

def json_value(value):
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    return value

def clean_row(row):
    return {k: json_value(v) for k, v in row.items()}

def get_connection():
    return pymysql.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "credit_health_db"),
        cursorclass=DictCursor,
        autocommit=False,
        charset="utf8mb4",
    )

def validate_payload(resource, payload, partial=False):
    cfg = RESOURCE_CONFIG[resource]
    if not isinstance(payload, dict):
        return "Request body must be a JSON object."
    unknown = set(payload) - set(cfg["columns"])
    if unknown:
        return "Unsupported field(s): " + ", ".join(sorted(unknown))
    if not partial:
        missing = [f for f in cfg["required"] if f not in payload or payload[f] in ("", None)]
        if missing:
            return "Missing required field(s): " + ", ".join(missing)
    if "credit_score" in payload:
        try:
            if not 300 <= int(payload["credit_score"]) <= 850:
                return "credit_score must be between 300 and 850."
        except (TypeError, ValueError):
            return "credit_score must be an integer."
    for field in ("monthly_income_usd", "monthly_expenses_usd", "savings_usd",
                  "loan_amount_usd", "monthly_emi_usd", "amount_due_usd",
                  "amount_paid_usd", "remaining_balance_usd",
                  "monthly_available_amount", "planned_amount_usd"):
        if field in payload:
            try:
                if float(payload[field]) < 0:
                    return f"{field} cannot be negative."
            except (TypeError, ValueError):
                return f"{field} must be numeric."
    if "loan_term_months" in payload and int(payload["loan_term_months"]) <= 0:
        return "loan_term_months must be greater than zero."
    if "total_months" in payload and int(payload["total_months"]) <= 0:
        return "total_months must be greater than zero."
    if "priority_order" in payload and int(payload["priority_order"]) <= 0:
        return "priority_order must be greater than zero."
    if resource == "financial-profiles" and payload.get("has_loan") not in (None, "Yes", "No"):
        return "has_loan must be Yes or No."
    return None

def create_app(test_config=None):
    app = Flask(__name__)
    app.config.update(test_config or {})
    allowed_origin = os.getenv("FRONTEND_ORIGIN", "http://localhost:5173")
    CORS(app, resources={r"/api/*": {"origins": allowed_origin}})

    @app.errorhandler(Exception)
    def handle_error(exc):
        if isinstance(exc, HTTPException):
            return jsonify({"error": exc.description}), exc.code
        if app.testing:
            raise exc
        app.logger.exception("Unhandled application error")
        return jsonify({"error": "Internal server error. Check backend logs."}), 500

    @app.get("/api/health")
    def health():
        try:
            conn = get_connection()
            conn.close()
            return jsonify({"status": "ok", "database": "connected"})
        except Exception as exc:
            return jsonify({"status": "error", "database": "unavailable",
                            "detail": str(exc)}), 503

    @app.get("/api/dashboard")
    def dashboard():
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) AS total_users FROM `user`")
                users = cur.fetchone()["total_users"]
                cur.execute("SELECT COUNT(*) AS total_loans, COALESCE(SUM(loan_amount_usd),0) AS loan_total FROM loan")
                loan = cur.fetchone()
                cur.execute("""SELECT COUNT(*) AS repayment_count,
                    COALESCE(SUM(CASE WHEN payment_status IN ('Pending','Overdue','Late') THEN 1 ELSE 0 END),0) AS pending_count,
                    COALESCE(SUM(remaining_balance_usd),0) AS outstanding
                    FROM repayment""")
                repayments = cur.fetchone()
                cur.execute("SELECT COUNT(*) AS plan_count FROM repayment_plan")
                plans = cur.fetchone()["plan_count"]
                cur.execute("""SELECT loan_type, COUNT(*) AS total_loans,
                    COALESCE(SUM(loan_amount_usd),0) AS total_amount
                    FROM loan GROUP BY loan_type ORDER BY total_amount DESC""")
                distribution = cur.fetchall()
                cur.execute("""SELECT payment_id, loan_id, installment_number, due_date,
                    payment_status, amount_due_usd, amount_paid_usd
                    FROM repayment ORDER BY due_date DESC LIMIT 6""")
                recent = cur.fetchall()
            return jsonify({
                "metrics": {
                    "users": users, "loans": loan["total_loans"],
                    "loan_total": json_value(loan["loan_total"]),
                    "repayments": repayments["repayment_count"],
                    "pending_repayments": repayments["pending_count"],
                    "outstanding": json_value(repayments["outstanding"]),
                    "plans": plans,
                },
                "loan_distribution": [clean_row(r) for r in distribution],
                "recent_repayments": [clean_row(r) for r in recent],
            })
        finally:
            conn.close()

    @app.get("/api/<resource>")
    def list_records(resource):
        if resource not in RESOURCE_CONFIG:
            return jsonify({"error": "Unknown resource"}), 404
        cfg = RESOURCE_CONFIG[resource]
        try:
            page = max(1, int(request.args.get("page", 1)))
            per_page = min(100, max(1, int(request.args.get("per_page", 10))))
        except ValueError:
            return jsonify({"error": "page and per_page must be integers"}), 400
        search = request.args.get("search", "").strip()
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                where, params = "", []
                if search and cfg.get("search"):
                    where = " WHERE " + " OR ".join(f"CAST(`{c}` AS CHAR) LIKE %s" for c in cfg["search"])
                    params = [f"%{search}%"] * len(cfg["search"])
                cur.execute(f"SELECT COUNT(*) AS n FROM {cfg['table']}{where}", params)
                total = cur.fetchone()["n"]
                cur.execute(
                    f"SELECT * FROM {cfg['table']}{where} ORDER BY `{cfg['pk']}` DESC LIMIT %s OFFSET %s",
                    params + [per_page, (page - 1) * per_page]
                )
                rows = [clean_row(r) for r in cur.fetchall()]
            return jsonify({"items": rows, "page": page, "per_page": per_page, "total": total,
                            "pages": (total + per_page - 1) // per_page})
        finally:
            conn.close()

    @app.post("/api/<resource>")
    def create_record(resource):
        if resource not in RESOURCE_CONFIG:
            return jsonify({"error": "Unknown resource"}), 404
        payload = request.get_json(silent=True) or {}
        error = validate_payload(resource, payload)
        if error:
            return jsonify({"error": error}), 400
        cfg = RESOURCE_CONFIG[resource]
        fields = list(payload.keys())
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                names = ", ".join(f"`{f}`" for f in fields)
                placeholders = ", ".join(["%s"] * len(fields))
                cur.execute(f"INSERT INTO {cfg['table']} ({names}) VALUES ({placeholders})",
                            [payload[f] for f in fields])
                new_id = payload.get(cfg["pk"], cur.lastrowid)
            conn.commit()
            return jsonify({"message": "Record created", "id": new_id}), 201
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    @app.get("/api/<resource>/<record_id>")
    def get_record(resource, record_id):
        if resource not in RESOURCE_CONFIG:
            return jsonify({"error": "Unknown resource"}), 404
        cfg = RESOURCE_CONFIG[resource]
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(f"SELECT * FROM {cfg['table']} WHERE `{cfg['pk']}`=%s", (record_id,))
                row = cur.fetchone()
            if not row:
                return jsonify({"error": "Record not found"}), 404
            return jsonify(clean_row(row))
        finally:
            conn.close()

    @app.put("/api/<resource>/<record_id>")
    def update_record(resource, record_id):
        if resource not in RESOURCE_CONFIG:
            return jsonify({"error": "Unknown resource"}), 404
        payload = request.get_json(silent=True) or {}
        error = validate_payload(resource, payload, partial=True)
        if error:
            return jsonify({"error": error}), 400
        if not payload:
            return jsonify({"error": "No fields supplied"}), 400
        cfg = RESOURCE_CONFIG[resource]
        fields = list(payload.keys())
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                assignments = ", ".join(f"`{f}`=%s" for f in fields)
                cur.execute(f"UPDATE {cfg['table']} SET {assignments} WHERE `{cfg['pk']}`=%s",
                            [payload[f] for f in fields] + [record_id])
                changed = cur.rowcount
            conn.commit()
            if changed == 0:
                return jsonify({"message": "No change made; verify the record exists."}), 200
            return jsonify({"message": "Record updated"})
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    @app.delete("/api/<resource>/<record_id>")
    def delete_record(resource, record_id):
        if resource not in RESOURCE_CONFIG:
            return jsonify({"error": "Unknown resource"}), 404
        cfg = RESOURCE_CONFIG[resource]
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(f"DELETE FROM {cfg['table']} WHERE `{cfg['pk']}`=%s", (record_id,))
                deleted = cur.rowcount
            conn.commit()
            if not deleted:
                return jsonify({"error": "Record not found"}), 404
            return jsonify({"message": "Record deleted"})
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    return app

app = create_app()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.getenv("PORT", "5000")), debug=os.getenv("FLASK_DEBUG") == "1")
