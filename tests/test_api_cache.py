import json
import time

from conftest import run_main_and_parse


def test_cache_miss_returns_found_false(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/api_cache.py")
    monkeypatch.setattr(module, "CACHE_FILE", tmp_path / "api_result_cache.json")
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["api_cache.py", "get", "monthly", "EUR", "0", "none"])
    assert rc == 0
    assert payload["found"] is False
    assert payload["payload"] == {}


def test_cache_hit_returns_stored_payload(load_module, tmp_path, monkeypatch, capsys, sample_api_payload):
    module = load_module("claude-usage-widget/contents/code/api_cache.py")
    monkeypatch.setattr(module, "CACHE_FILE", tmp_path / "api_result_cache.json")
    run_main_and_parse(
        module,
        monkeypatch,
        capsys,
        ["api_cache.py", "set", "monthly", "EUR", "39", "selected", json.dumps(sample_api_payload)],
    )
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["api_cache.py", "get", "monthly", "EUR", "39", "selected"])
    assert rc == 0
    assert payload["found"] is True
    assert payload["payload"] == sample_api_payload


def test_expired_cache_is_a_miss(load_module, tmp_path, monkeypatch, capsys, sample_api_payload):
    module = load_module("claude-usage-widget/contents/code/api_cache.py")
    cache_file = tmp_path / "api_result_cache.json"
    monkeypatch.setattr(module, "CACHE_FILE", cache_file)
    stale_entry = {
        module.make_key("monthly", "EUR", "39", "selected"): {
            "_ts": int(time.time()) - module.DEFAULT_TTL_SECONDS - 10,
            "payload": sample_api_payload,
        }
    }
    cache_file.write_text(json.dumps(stale_entry))
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["api_cache.py", "get", "monthly", "EUR", "39", "selected"])
    assert rc == 0
    assert payload["found"] is False


def test_cache_key_changes_with_arguments(load_module):
    module = load_module("claude-usage-widget/contents/code/api_cache.py")
    keys = {
        module.make_key("daily", "EUR", "0", "none"),
        module.make_key("monthly", "EUR", "0", "none"),
        module.make_key("monthly", "USD", "0", "none"),
        module.make_key("monthly", "USD", "39", "selected"),
    }
    assert len(keys) == 4
