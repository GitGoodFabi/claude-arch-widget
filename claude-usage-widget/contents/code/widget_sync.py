#!/usr/bin/env python3
"""Reads and writes shared widget presets grouped by mode."""

import json
import sys
import time
from hashlib import sha256
from pathlib import Path


SYNC_FILE = Path.home() / ".config" / "claude-widget" / "mode_sync.json"
VALID_MODES = {"claudeai", "api"}
REDACTED_MARKERS = ("sessionkey", "api_key", "bearer")


def load_store() -> dict:
    if not SYNC_FILE.exists():
        return {}
    try:
        data = json.loads(SYNC_FILE.read_text())
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def save_store(data: dict) -> None:
    SYNC_FILE.parent.mkdir(parents=True, exist_ok=True)
    SYNC_FILE.write_text(json.dumps(data, ensure_ascii=True, separators=(",", ":")))


def get_mode_entry(store: dict, mode: str) -> dict | None:
    entry = store.get(mode)
    if not isinstance(entry, dict):
        return None
    if isinstance(entry.get("settings"), dict):
        return {
            "_rev": str(entry.get("_rev", "")),
            "settings": dict(entry["settings"]),
        }
    # Legacy format: the mode value itself was the settings object.
    settings = {k: v for k, v in entry.items() if not k.startswith("_")}
    fallback_rev = sha256(
        json.dumps(settings, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    return {
        "_rev": str(entry.get("_rev", fallback_rev)),
        "settings": settings,
    }


def mode_response(action: str, mode: str, entry: dict | None) -> dict:
    settings = sanitize_settings(dict(entry.get("settings", {})) if entry else {})
    revision = str(entry.get("_rev", "")) if entry else ""
    return {
        "ok": True,
        "action": action,
        "mode": mode,
        "found": entry is not None,
        "revision": revision,
        "settings": settings,
    }


def sanitize_settings(value):
    if isinstance(value, dict):
        sanitized = {}
        for key, item in value.items():
            key_text = str(key)
            lowered = key_text.lower()
            if any(marker in lowered for marker in REDACTED_MARKERS):
                continue
            sanitized[key_text] = sanitize_settings(item)
        return sanitized
    if isinstance(value, list):
        return [sanitize_settings(item) for item in value]
    if isinstance(value, str):
        lowered = value.lower()
        if any(marker in lowered for marker in REDACTED_MARKERS):
            return "[redacted]"
    return value


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({"ok": False, "error": "usage: widget_sync.py <get|set> <claudeai|api> [args]"}))
        return 1

    action = sys.argv[1]
    mode = sys.argv[2]
    if mode not in VALID_MODES:
        print(json.dumps({"ok": False, "error": f"invalid mode: {mode}"}))
        return 1

    store = load_store()

    if action == "get":
        entry = get_mode_entry(store, mode)
        if entry is not None and store.get(mode) != entry:
            store[mode] = entry
            save_store(store)
        print(json.dumps(mode_response("get", mode, entry)))
        return 0

    if action == "set":
        if len(sys.argv) < 4:
            print(json.dumps({"ok": False, "error": "missing json payload"}))
            return 1
        try:
            settings = json.loads(sys.argv[3])
        except json.JSONDecodeError as exc:
            print(json.dumps({"ok": False, "error": f"invalid json payload: {exc}"}))
            return 1
        if not isinstance(settings, dict):
            print(json.dumps({"ok": False, "error": "payload must be a json object"}))
            return 1
        store[mode] = {
            "_rev": str(time.time_ns()),
            "settings": settings,
        }
        save_store(store)
        print(json.dumps(mode_response("set", mode, get_mode_entry(store, mode))))
        return 0

    print(json.dumps({"ok": False, "error": f"invalid action: {action}"}))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
