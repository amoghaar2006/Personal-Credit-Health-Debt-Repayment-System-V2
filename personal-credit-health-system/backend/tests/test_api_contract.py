import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app

def test_health_route_is_registered():
    app = create_app({"TESTING": True})
    rules = {rule.rule for rule in app.url_map.iter_rules()}
    assert "/api/health" in rules
    assert "/api/dashboard" in rules
    assert "/api/<resource>" in rules
