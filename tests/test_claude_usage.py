import json
import sys
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError

import pytest


class FakeResponse:
    def __init__(self, payload):
        self.payload = json.dumps(payload).encode()

    def read(self):
        return self.payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


def test_time_until_returns_now_for_past_timestamp(load_module):
    module = load_module("claude_usage.py")
    past = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    assert module.time_until(past) == "now"


def test_time_until_formats_hours_and_minutes(load_module):
    module = load_module("claude_usage.py")
    future = (datetime.now(timezone.utc) + timedelta(hours=2, minutes=15)).isoformat()
    assert module.time_until(future).startswith("2h ")


def test_missing_session_key_produces_structured_error(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude_usage.py")
    monkeypatch.setattr(module, "COOKIE_FILE", tmp_path / "session.txt")
    monkeypatch.setattr(sys, "argv", ["claude_usage.py"])
    with pytest.raises(SystemExit):
        module.main()
    payload = json.loads(capsys.readouterr().out.strip())
    assert payload["auth"] is True
    assert "error" in payload


def test_http_401_403_produce_structured_auth_error(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude_usage.py")
    session_file = tmp_path / "session.txt"
    session_file.write_text("session")
    monkeypatch.setattr(module, "COOKIE_FILE", session_file)

    def raise_401(*args, **kwargs):
        raise HTTPError(url="https://claude.ai/api/organizations", code=401, msg="Unauthorized", hdrs=None, fp=None)

    monkeypatch.setattr(module.urllib.request, "urlopen", raise_401)
    monkeypatch.setattr(sys, "argv", ["claude_usage.py"])
    with pytest.raises(SystemExit):
        module.main()
    payload = json.loads(capsys.readouterr().out.strip())
    assert payload["auth"] is True
    assert "401" in payload["error"]


ORGS_MULTI = [
    {"uuid": "console-a", "name": "Console (api_individual)", "capabilities": ["api", "api_individual"]},
    {"uuid": "console-b", "name": "Console (no credits)", "capabilities": ["api"]},
    {"uuid": "team-seat", "name": "Acme Team", "capabilities": ["raven", "chat"], "raven_type": "team"},
]


def _load_with_org_file(load_module, tmp_path, monkeypatch, override: str | None = None):
    module = load_module("claude_usage.py")
    org_file = tmp_path / "org_id.txt"
    if override is not None:
        org_file.write_text(override)
    monkeypatch.setattr(module, "ORG_ID_FILE", org_file)
    return module


def test_pick_org_id_prefers_chat_org_over_api_orgs(load_module, tmp_path, monkeypatch):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch)
    assert module.pick_org_id(ORGS_MULTI) == "team-seat"


def test_pick_org_id_ranks_max_above_pro_above_raven(load_module, tmp_path, monkeypatch):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch)
    orgs = [
        {"uuid": "raven-org", "capabilities": ["raven", "chat"]},
        {"uuid": "pro-org", "capabilities": ["chat", "claude_pro"]},
        {"uuid": "max-org", "capabilities": ["chat", "claude_max"]},
    ]
    assert module.pick_org_id(orgs) == "max-org"
    assert module.pick_org_id(orgs[:2]) == "pro-org"


def test_pick_org_id_falls_back_to_id_field(load_module, tmp_path, monkeypatch):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch)
    assert module.pick_org_id([{"id": "legacy-id", "capabilities": ["chat"]}]) == "legacy-id"


def test_pick_org_id_override_file_wins_over_heuristic(load_module, tmp_path, monkeypatch):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch, override="  console-b\n")
    assert module.pick_org_id(ORGS_MULTI) == "console-b"


def test_pick_org_id_ignores_blank_override_file(load_module, tmp_path, monkeypatch):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch, override="   \n")
    assert module.pick_org_id(ORGS_MULTI) == "team-seat"


def test_pick_org_id_returns_none_when_all_orgs_are_api_only(load_module, tmp_path, monkeypatch):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch)
    assert module.pick_org_id(ORGS_MULTI[:2]) is None
    assert module.pick_org_id([]) is None


def test_main_errors_with_json_shape_when_no_chat_org(load_module, tmp_path, monkeypatch, capsys):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch)
    session_file = tmp_path / "session.txt"
    session_file.write_text("session")
    monkeypatch.setattr(module, "COOKIE_FILE", session_file)
    monkeypatch.setattr(module, "make_request", lambda url, key: ORGS_MULTI[:2])
    monkeypatch.setattr(sys, "argv", ["claude_usage.py"])

    with pytest.raises(SystemExit) as exc:
        module.main()
    assert exc.value.code == 1
    payload = json.loads(capsys.readouterr().out.strip())
    assert payload["auth"] is False
    assert "org_id.txt" in payload["error"]


def test_main_uses_chat_org_and_reports_it(load_module, tmp_path, monkeypatch, capsys):
    module = _load_with_org_file(load_module, tmp_path, monkeypatch)
    session_file = tmp_path / "session.txt"
    session_file.write_text("session")
    monkeypatch.setattr(module, "COOKIE_FILE", session_file)

    requested = []

    def fake_request(url, key):
        requested.append(url)
        if url == module.ORGS_URL:
            return ORGS_MULTI
        return {
            "five_hour": {"utilization": 12, "resets_at": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()},
            "seven_day": {"utilization": 34, "resets_at": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()},
            "extra_usage": {"is_enabled": False},
        }

    monkeypatch.setattr(module, "make_request", fake_request)
    monkeypatch.setattr(sys, "argv", ["claude_usage.py"])
    module.main()

    payload = json.loads(capsys.readouterr().out.strip())
    assert requested[1] == "https://claude.ai/api/organizations/team-seat/usage"
    assert payload["org"] == {"uuid": "team-seat", "name": "Acme Team"}
    assert payload["session"]["utilization"] == 12
    assert payload["weekly"]["utilization"] == 34
