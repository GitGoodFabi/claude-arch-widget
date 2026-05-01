#!/usr/bin/env python3
"""Fetches Claude usage data and prints JSON for the Plasma widget.

Usage: python3 claude_usage.py [oauth]
  (no args) — reads session cookie from ~/.config/claude-widget/session.txt
  oauth     — reads OAuth token from ~/.claude/.credentials.json
"""

import json
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ORGS_URL = "https://claude.ai/api/organizations"
COOKIE_FILE = Path.home() / ".config" / "claude-widget" / "session.txt"
CREDENTIALS_FILE = Path.home() / ".claude" / ".credentials.json"


def load_session_key():
    if not COOKIE_FILE.exists():
        print(json.dumps({
            "error": f"No session key found. Run setup:\nmkdir -p {COOKIE_FILE.parent} && echo 'YOUR_SESSION_KEY' > {COOKIE_FILE}",
            "auth": True,
        }))
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
        print(json.dumps({
            "error": f"HTTP {e.code} fetching orgs. Session key may be expired.",
            "auth": e.code in (401, 403),
        }))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e), "auth": False}))
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
        print(json.dumps({"error": f"HTTP {e.code} fetching usage.", "auth": e.code in (401, 403)}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e), "auth": False}))
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


def _load_oauth_token() -> tuple:
    if not CREDENTIALS_FILE.exists():
        print(json.dumps({
            "error": "~/.claude/.credentials.json not found. Log in with `claude`.",
            "auth": True,
        }))
        sys.exit(1)
    try:
        creds = json.loads(CREDENTIALS_FILE.read_text())
        oauth = creds.get("claudeAiOauth", {})
        token = oauth.get("accessToken", "")
        tier  = oauth.get("rateLimitTier", "")
    except Exception as e:
        print(json.dumps({"error": f"Could not parse credentials: {e}", "auth": True}))
        sys.exit(1)
    if not token:
        print(json.dumps({"error": "No OAuth token in credentials file. Run `claude`.", "auth": True}))
        sys.exit(1)
    plan = {
        "default_claude_pro": "Pro",
        "claude_max_5x": "Max 5×",
        "claude_max_20x": "Max 20×",
    }.get(tier, tier or "")
    return token, plan


def main_oauth():
    token, plan = _load_oauth_token()
    req = urllib.request.Request("https://api.anthropic.com/api/oauth/usage")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("anthropic-beta", "oauth-2025-04-20")
    req.add_header("User-Agent", "claude-code/1.0")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(json.dumps({
            "error": f"Token rejected (HTTP {e.code}). Run `claude` to refresh.",
            "auth": True,
        }))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e), "auth": False}))
        sys.exit(1)

    five_hour = data.get("five_hour") or {}
    seven_day = data.get("seven_day") or {}
    output = {
        "session": {
            "utilization": five_hour.get("utilization", 0),
            "resets_in":   time_until(five_hour["resets_at"]) if five_hour.get("resets_at") else "?",
            "resets_at":   five_hour.get("resets_at", ""),
        },
        "weekly": {
            "utilization": seven_day.get("utilization", 0),
            "resets_in":   time_until(seven_day["resets_at"]) if seven_day.get("resets_at") else "?",
            "resets_at":   seven_day.get("resets_at", ""),
        },
        "plan": plan,
    }
    print(json.dumps(output))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "oauth":
        main_oauth()
    else:
        main()
