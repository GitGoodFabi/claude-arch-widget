import json
import sys

import pytest

from conftest import run_main_and_parse


def test_get_missing_file_returns_not_found(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    monkeypatch.setattr(module, "SYNC_FILE", tmp_path / "mode_sync.json")
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "get", "api"])
    assert rc == 0
    assert payload["found"] is False
    assert payload["settings"] == {}


def test_set_then_get_round_trips_settings(load_module, tmp_path, monkeypatch, capsys, sample_sync_settings):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    monkeypatch.setattr(module, "SYNC_FILE", tmp_path / "mode_sync.json")
    rc, payload = run_main_and_parse(
        module,
        monkeypatch,
        capsys,
        ["widget_sync.py", "set", "api", json.dumps(sample_sync_settings)],
    )
    assert rc == 0
    assert payload["settings"] == sample_sync_settings

    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "get", "api"])
    assert rc == 0
    assert payload["found"] is True
    assert payload["settings"] == sample_sync_settings


def test_set_increments_revision_on_each_write(load_module, tmp_path, monkeypatch, capsys, sample_sync_settings):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    monkeypatch.setattr(module, "SYNC_FILE", tmp_path / "mode_sync.json")
    revisions = iter([111, 222])
    monkeypatch.setattr(module.time, "time_ns", lambda: next(revisions))

    _, first = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "set", "api", json.dumps(sample_sync_settings)])
    _, second = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "set", "api", json.dumps(sample_sync_settings)])
    assert first["revision"] == "111"
    assert second["revision"] == "222"


def test_legacy_format_is_migrated_on_get(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    sync_file = tmp_path / "mode_sync.json"
    monkeypatch.setattr(module, "SYNC_FILE", sync_file)
    sync_file.write_text(json.dumps({"api": {"colorTheme": "violet", "apiCurrency": "EUR"}}))

    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "get", "api"])
    assert rc == 0
    assert payload["found"] is True
    assert payload["settings"] == {"colorTheme": "violet", "apiCurrency": "EUR"}

    migrated = json.loads(sync_file.read_text())
    assert migrated["api"]["settings"] == {"colorTheme": "violet", "apiCurrency": "EUR"}
    assert "_rev" in migrated["api"]


def test_invalid_mode_returns_structured_error(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    monkeypatch.setattr(module, "SYNC_FILE", tmp_path / "mode_sync.json")
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "get", "invalid"])
    assert rc == 1
    assert payload["ok"] is False


def test_corrupted_json_is_handled_gracefully(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    sync_file = tmp_path / "mode_sync.json"
    monkeypatch.setattr(module, "SYNC_FILE", sync_file)
    sync_file.write_text("{not-json")
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "get", "api"])
    assert rc == 0
    assert payload["found"] is False
    assert payload["settings"] == {}


def test_two_sequential_sets_have_different_revisions(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    monkeypatch.setattr(module, "SYNC_FILE", tmp_path / "mode_sync.json")
    revisions = iter([1001, 1002])
    monkeypatch.setattr(module.time, "time_ns", lambda: next(revisions))
    _, first = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "set", "claudeai", '{"colorTheme":"amber"}'])
    _, second = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "set", "claudeai", '{"colorTheme":"ocean"}'])
    assert first["revision"] != second["revision"]


def test_get_output_redacts_secret_like_content(load_module, tmp_path, monkeypatch, capsys):
    module = load_module("claude-usage-widget/contents/code/widget_sync.py")
    sync_file = tmp_path / "mode_sync.json"
    monkeypatch.setattr(module, "SYNC_FILE", sync_file)
    sync_file.write_text(json.dumps({
        "api": {
            "sessionKey": "secret",
            "api_key": "secret-2",
            "header": "Bearer abc",
            "colorTheme": "violet",
        }
    }))
    rc, payload = run_main_and_parse(module, monkeypatch, capsys, ["widget_sync.py", "get", "api"])
    assert rc == 0
    text = json.dumps(payload)
    assert "sessionKey" not in text
    assert "api_key" not in text
    assert "Bearer" not in text
