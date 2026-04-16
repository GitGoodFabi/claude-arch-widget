import json
import os
import stat
import subprocess
import sys

import pytest

from conftest import run_main_and_parse


pytestmark = pytest.mark.security


def escape_shell_arg(value: str) -> str:
    return value.replace("'", "'\\''")


@pytest.mark.parametrize(
    "value",
    [
        "'; rm -rf ~; echo '",
        "`id`",
        "$(whoami)",
        "line1\nline2",
        "",
    ],
)
def test_escape_shell_arg_keeps_single_quote_context(value):
    escaped = escape_shell_arg(value)
    result = subprocess.run(
        ["bash", "-lc", f"printf '%s' '{escaped}'"],
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stdout == value


def test_simulated_file_permissions_are_600(tmp_path):
    config_dir = tmp_path / ".config" / "claude-widget"
    config_dir.mkdir(parents=True)
    api_key = config_dir / "api_key.txt"
    session = config_dir / "session.txt"
    api_key.write_text("secret")
    session.write_text("secret")
    os.chmod(api_key, 0o600)
    os.chmod(session, 0o600)
    assert stat.S_IMODE(api_key.stat().st_mode) == 0o600
    assert stat.S_IMODE(session.stat().st_mode) == 0o600


def test_widget_sync_get_does_not_leak_credential_markers(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    sync_file = tmp_path / "mode_sync.json"
    monkeypatch.setattr(module, "SYNC_FILE", sync_file)
    sync_file.write_text(json.dumps({
        "api": {
            "settings": {
                "sessionKey": "abc",
                "api_key": "def",
                "authorization": "Bearer xyz",
                "colorTheme": "violet",
            }
        }
    }))
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "get", "api"])
    assert rc == 0
    text = json.dumps(payload)
    assert "sessionKey" not in text
    assert "api_key" not in text
    assert "Bearer" not in text


def test_api_usage_never_echoes_raw_api_key(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    secret = "sk-ant-admin-secret-value"
    key_file = tmp_path / "api_key.txt"
    key_file.write_text(secret)
    monkeypatch.setattr(module, "API_KEY_FILE", key_file)

    class FakeResponse:
        def __init__(self, payload):
            self.payload = json.dumps(payload).encode()

        def read(self):
            return self.payload

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(request, timeout=10):
        url = request.full_url if hasattr(request, "full_url") else str(request)
        if url.endswith("/organizations/me"):
            return FakeResponse({"id": "org-1"})
        if "/organizations/usage_report/messages" in url:
            return FakeResponse({"data": [{"results": [{"model": "claude-sonnet-4-6", "uncached_input_tokens": 1000, "output_tokens": 0}]}], "has_more": False})
        if "/organizations/cost_report" in url:
            return FakeResponse({"data": [], "has_more": False})
        if "open.er-api.com" in url:
            return FakeResponse({"rates": {"EUR": 0.92}})
        raise AssertionError(url)

    monkeypatch.setattr(module.urllib.request, "urlopen", fake_urlopen)
    monkeypatch.setattr(sys, "argv", ["api_usage.py", "monthly", "USD", "0", "none"])
    module.main()
    out = capsys.readouterr().out.strip()
    assert secret not in out
