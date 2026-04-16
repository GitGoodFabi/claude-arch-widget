import io
import json
import sys
from pathlib import Path
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


def make_fake_urlopen(usage_rows, cost_rows=None, eur_rate=0.92):
    def _urlopen(request, timeout=10):
        url = request.full_url if hasattr(request, "full_url") else str(request)
        if url.endswith("/organizations/me"):
            return FakeResponse({"id": "org-1"})
        if "/organizations/usage_report/messages" in url:
            return FakeResponse({"data": [{"results": usage_rows}], "has_more": False})
        if "/organizations/cost_report" in url:
            return FakeResponse({"data": [{"results": cost_rows or []}], "has_more": False})
        if "open.er-api.com" in url:
            return FakeResponse({"rates": {"EUR": eur_rate}})
        raise AssertionError(f"unexpected url {url}")

    return _urlopen


def run_api_usage(module, monkeypatch, capsys, argv):
    monkeypatch.setattr(sys, "argv", argv)
    module.main()
    return json.loads(capsys.readouterr().out.strip())


def test_pricing_lookup_matches_known_models(load_module):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    assert module._price("claude-sonnet-4-6") == (3.00, 15.00, 0.300, 3.750)
    assert module._price("claude-opus-4-1") == (15.00, 75.00, 1.500, 18.750)


def test_pricing_lookup_falls_back_for_unknown_model(load_module):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    assert module._price("totally-unknown-model") == module._DEFAULT_PRICING


@pytest.mark.parametrize(
    ("budget_cap", "expected_pct"),
    [(0, 0.0), (3, 50.0), (1.5, 100.0), (1, 100.0)],
)
def test_budget_percentage_calculation(load_module, tmp_path, monkeypatch, capsys, budget_cap, expected_pct):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    key_file = tmp_path / "api_key.txt"
    key_file.write_text("sk-ant-admin-secret")
    monkeypatch.setattr(module, "API_KEY_FILE", key_file)
    usage_rows = [{"model": "claude-sonnet-4-6", "uncached_input_tokens": 500_000, "output_tokens": 0}]
    monkeypatch.setattr(module.urllib.request, "urlopen", make_fake_urlopen(usage_rows))
    payload = run_api_usage(module, monkeypatch, capsys, ["api_usage.py", "monthly", "USD", str(budget_cap), "selected"])
    assert payload["budget"]["pct"] == expected_pct


def test_cost_display_formatting(load_module):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    assert module._fmt_cost(0.308, "€") == "€0.308"
    assert module._fmt_cost(0.308, "$") == "$0.308"
    assert module._fmt_cost(2.5, "€") == "€2.50"


def test_by_model_sorted_by_token_count_desc(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    key_file = tmp_path / "api_key.txt"
    key_file.write_text("sk-ant-admin-secret")
    monkeypatch.setattr(module, "API_KEY_FILE", key_file)
    usage_rows = [
        {"model": "claude-opus-4-1", "uncached_input_tokens": 100_000, "output_tokens": 0},
        {"model": "claude-haiku-4-5", "uncached_input_tokens": 500_000, "output_tokens": 0},
    ]
    monkeypatch.setattr(module.urllib.request, "urlopen", make_fake_urlopen(usage_rows))
    payload = run_api_usage(module, monkeypatch, capsys, ["api_usage.py", "monthly", "USD", "0", "none"])
    assert [row["display"] for row in payload["by_model"][:2]] == ["Haiku 4.5", "Opus 4.1"]


def test_missing_or_empty_api_key_file_returns_structured_error(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    missing = tmp_path / "missing_api_key.txt"
    monkeypatch.setattr(module, "API_KEY_FILE", missing)
    monkeypatch.setattr(sys, "argv", ["api_usage.py"])
    with pytest.raises(SystemExit):
        module.main()
    payload = json.loads(capsys.readouterr().out.strip())
    assert "error" in payload

    empty = tmp_path / "empty_api_key.txt"
    empty.write_text("")
    monkeypatch.setattr(module, "API_KEY_FILE", empty)
    monkeypatch.setattr(sys, "argv", ["api_usage.py"])
    with pytest.raises(SystemExit):
        module.main()
    payload = json.loads(capsys.readouterr().out.strip())
    assert "error" in payload


def test_api_usage_output_never_echoes_raw_api_key(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/api_usage.py")
    secret = "sk-ant-admin-super-secret"
    key_file = tmp_path / "api_key.txt"
    key_file.write_text(secret)
    monkeypatch.setattr(module, "API_KEY_FILE", key_file)
    usage_rows = [{"model": "claude-sonnet-4-6", "uncached_input_tokens": 100_000, "output_tokens": 0}]
    monkeypatch.setattr(module.urllib.request, "urlopen", make_fake_urlopen(usage_rows))
    payload = run_api_usage(module, monkeypatch, capsys, ["api_usage.py", "monthly", "USD", "0", "none"])
    assert secret not in json.dumps(payload)
