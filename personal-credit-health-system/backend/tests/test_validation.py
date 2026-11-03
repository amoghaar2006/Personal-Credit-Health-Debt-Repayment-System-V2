import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import validate_payload

def test_missing_required_fields_rejected():
    assert "Missing required" in validate_payload("loans", {"loan_id": "L1"})

def test_credit_score_range():
    payload = {"credit_score": 200}
    assert "between 300 and 850" in validate_payload("financial-profiles", payload, partial=True)

def test_unknown_columns_rejected():
    assert "Unsupported field" in validate_payload("users", {"user_id": "U1", "admin": True})

def test_negative_loan_amount_rejected():
    assert "cannot be negative" in validate_payload("loans", {"loan_amount_usd": -10}, partial=True)

def test_valid_user_payload():
    assert validate_payload("users", {"user_id": "U123"}) is None
