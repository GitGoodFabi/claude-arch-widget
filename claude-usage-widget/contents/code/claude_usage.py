#!/usr/bin/env python3
"""Fetches Claude Pro usage data from claude.ai and prints JSON for the Plasma widget."""

import json
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ORGS_URL = "https://claude.ai/api/organizations"
COOKIE_FILE = Path.home() / ".config" / "claude-widget" / "session.txt"
ORG_ID_FILE = Path.home() / ".config" / "claude-widget" / "org_id.txt"

# Only orgs with "chat" in capabilities serve /usage data; API-only Console orgs
# return no five_hour block. Among chat orgs, prefer the richest plan.
PLAN_PREFERENCE = ("claude_max", "claude_pro", "raven")


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


def org_capabilities(org):
    caps = org.get("capabilities") or []
    return [c for c in caps if isinstance(c, str)]


def plan_score(org):
    """Ranks a chat org by plan; higher wins, 0 means no known plan capability."""
    caps = org_capabilities(org)
    for i, cap in enumerate(PLAN_PREFERENCE):
        if cap in caps:
            return len(PLAN_PREFERENCE) - i
    return 0


def pick_org_id(orgs):
    """Returns the UUID of the org that serves usage data, or None.

    A manual override in org_id.txt always wins. Otherwise the chat-capable orgs
    are ranked by plan preference — accounts with a Console org get several
    API-only orgs back, and those have no usage data.
    """
    try:
        override = ORG_ID_FILE.read_text().strip()
    except OSError:
        override = ""
    if override:
        return override

    chat_orgs = [
        org for org in orgs
        if isinstance(org, dict) and "chat" in org_capabilities(org)
    ]
    for org in sorted(chat_orgs, key=plan_score, reverse=True):
        org_id = org.get("uuid") or org.get("id")
        if org_id:
            return org_id
    return None


def make_request(url, session_key):
    req = urllib.request.Request(url)
    req.add_header("Cookie", f"sessionKey={session_key}")
    req.add_header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
    req.add_header("Accept", "application/json")
    req.add_header("Referer", "https://claude.ai/settings/usage")
    req.add_header("Origin", "https://claude.ai")
    req.add_header("anthropic-client-platform", "web_claude_ai")
    with urllib.request.urlopen(req, timeout=10) as resp:
        body = resp.read()
        if not body or body[:1] not in (b"{", b"["):
            raise ValueError("Session key has expired — open widget settings and click 'Extract from browser'")
        return json.loads(body)


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

    if not isinstance(orgs, list):
        orgs = []

    org_id = pick_org_id(orgs)

    if not org_id:
        print(json.dumps({
            "error": f"No claude.ai organization found for this account. If you have several orgs, put the right UUID in {ORG_ID_FILE}",
            "auth": False,
        }))
        sys.exit(1)

    org_name = next(
        (org.get("name", "") for org in orgs
         if isinstance(org, dict) and (org.get("uuid") or org.get("id")) == org_id),
        "",
    )

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
        "org": {
            "uuid": org_id,
            "name": org_name,
        },
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
