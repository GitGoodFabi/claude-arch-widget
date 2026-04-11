#!/usr/bin/env python3
"""Fetches Claude Pro usage data from claude.ai and prints JSON for the Plasma widget."""

import json
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ORGS_URL = "https://claude.ai/api/organizations"
COOKIE_FILE = Path.home() / ".config" / "claude-widget" / "session.txt"


def load_session_key():
    if not COOKIE_FILE.exists():
        print(json.dumps({"error": f"No session key found. Run setup:\nmkdir -p {COOKIE_FILE.parent} && echo 'YOUR_SESSION_KEY' > {COOKIE_FILE}"}))
        sys.exit(1)
    return COOKIE_FILE.read_text().strip()


def time_until(iso_str: str) -> str:
    """Returns human-readable time until a reset timestamp."""
    dt = datetime.fromisoformat(iso_str)
    now = datetime.now(timezone.utc)
    delta = dt - now
    if delta.total_seconds() <= 0:
        return "now"
    total_minutes = int(delta.total_seconds() // 60)
    hours, minutes = divmod(total_minutes, 60)
    if hours > 0:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def make_request(url, session_key):
    req = urllib.request.Request(url)
    req.add_header("Cookie", f"sessionKey={session_key}")
    req.add_header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
    req.add_header("Accept", "application/json")
    req.add_header("Referer", "https://claude.ai/settings/usage")
    req.add_header("Origin", "https://claude.ai")
    req.add_header("anthropic-client-platform", "web_claude_ai")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def main():
    session_key = load_session_key()

    try:
        orgs = make_request(ORGS_URL, session_key)
    except urllib.error.HTTPError as e:
        print(json.dumps({"error": f"HTTP {e.code} fetching orgs. Session key may be expired."}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

    # Pick first active org
    org_id = None
    for org in orgs:
        org_id = org.get("uuid") or org.get("id")
        if org_id:
            break

    if not org_id:
        print(json.dumps({"error": "Could not find organization ID"}))
        sys.exit(1)

    usage_url = f"https://claude.ai/api/organizations/{org_id}/usage"

    try:
        data = make_request(usage_url, session_key)
    except urllib.error.HTTPError as e:
        print(json.dumps({"error": f"HTTP {e.code} fetching usage."}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

    five_hour = data.get("five_hour") or {}
    seven_day = data.get("seven_day") or {}
    extra = data.get("extra_usage") or {}

    output = {
        "session": {
            "utilization": five_hour.get("utilization", 0),
            "resets_in": time_until(five_hour["resets_at"]) if five_hour.get("resets_at") else "?",
            "resets_at": five_hour.get("resets_at", ""),
        },
        "weekly": {
            "utilization": seven_day.get("utilization", 0),
            "resets_in": time_until(seven_day["resets_at"]) if seven_day.get("resets_at") else "?",
            "resets_at": seven_day.get("resets_at", ""),
        },
        "extra_usage": {
            "enabled": extra.get("is_enabled", False),
            "monthly_limit": extra.get("monthly_limit"),
            "used_credits": extra.get("used_credits"),
        },
    }

    print(json.dumps(output))


if __name__ == "__main__":
    main()
