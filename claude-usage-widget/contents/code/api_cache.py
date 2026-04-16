#!/usr/bin/env python3
"""Shared local cache for API widget results."""

import json
import sys
import time
from pathlib import Path


CACHE_FILE = Path.home() / ".config" / "claude-widget" / "api_result_cache.json"
DEFAULT_TTL_SECONDS = 600
CACHE_VERSION = "v2"


def load_cache() -> dict:
    if not CACHE_FILE.exists():
        return {}
    try:
        data = json.loads(CACHE_FILE.read_text())
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def save_cache(data: dict) -> None:
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(data, ensure_ascii=True, separators=(",", ":")))


def make_key(window: str, currency: str, budget_cap: str, budget_mode: str) -> str:
    return "|".join([CACHE_VERSION, window, currency, budget_cap, budget_mode])


def wrap_payload(payload: dict) -> dict:
    return {
        "_ts": int(time.time()),
        "payload": payload,
    }


def unwrap_payload(entry) -> dict | None:
    if not isinstance(entry, dict):
        return None
    if isinstance(entry.get("payload"), dict):
        return dict(entry["payload"])
    return dict(entry)


def is_fresh(entry, ttl_seconds: int = DEFAULT_TTL_SECONDS) -> bool:
    if not isinstance(entry, dict):
        return False
    ts = entry.get("_ts")
    if ts is None:
        return True
    try:
        return (time.time() - float(ts)) <= ttl_seconds
    except (TypeError, ValueError):
        return False


def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "error": "usage: api_cache.py <get|set> ..."}))
        return 1

    action = sys.argv[1]
    store = load_cache()

    if action == "get":
        if len(sys.argv) < 6:
            print(json.dumps({"ok": False, "error": "usage: api_cache.py get <window> <currency> <budget_cap> <budget_mode>"}))
            return 1
        key = make_key(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
        entry = store.get(key)
        payload = unwrap_payload(entry) if is_fresh(entry) else None
        print(json.dumps({
            "ok": True,
            "action": "get",
            "found": isinstance(payload, dict),
            "payload": payload if isinstance(payload, dict) else {},
        }))
        return 0

    if action == "set":
        if len(sys.argv) < 7:
            print(json.dumps({"ok": False, "error": "usage: api_cache.py set <window> <currency> <budget_cap> <budget_mode> <json>"}))
            return 1
        key = make_key(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
        try:
            payload = json.loads(sys.argv[6])
        except json.JSONDecodeError as exc:
            print(json.dumps({"ok": False, "error": f"invalid json payload: {exc}"}))
            return 1
        if not isinstance(payload, dict):
            print(json.dumps({"ok": False, "error": "payload must be a json object"}))
            return 1
        store[key] = wrap_payload(payload)
        save_cache(store)
        print(json.dumps({"ok": True, "action": "set"}))
        return 0

    print(json.dumps({"ok": False, "error": f"invalid action: {action}"}))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
