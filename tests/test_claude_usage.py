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


@pytest.mark.parametrize("script", [
    "claude_usage.py",
    "claude-usage-widget/contents/code/claude_usage.py",
])
@pytest.mark.parametrize("seconds,expected", [
    (-1, "now"),
    (0, "now"),
    (59 * 60, "59m"),
    (23 * 3600 + 59 * 60, "23h 59m"),
    (24 * 3600, "24h 0m"),
    (24 * 3600 + 1, "1d 0h"),
    (25 * 3600 + 30 * 60, "1d 1h"),
    (48 * 3600, "2d 0h"),
    (116 * 3600 + 25 * 60, "4d 20h"),
])
def test_reset_countdown_day_format(script, seconds, expected, load_module, monkeypatch):
    module = load_module(script)
    now = datetime(2026, 10, 25, 12, tzinfo=timezone.utc)

    class FixedDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return now

    monkeypatch.setattr(module, "datetime", FixedDatetime)
    assert module.time_until((now + timedelta(seconds=seconds)).isoformat()) == expected
