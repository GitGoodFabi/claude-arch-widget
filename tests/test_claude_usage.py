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
