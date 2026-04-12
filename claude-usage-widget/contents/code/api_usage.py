#!/usr/bin/env python3
"""Fetches Anthropic API token usage and cost data for the Plasma widget.

Usage: python3 api_usage.py [window] [currency] [budget_cap]
  window     : daily | weekly | monthly  (default: monthly)
  currency   : EUR | USD                 (default: EUR)
  budget_cap : float, 0 = no cap        (default: 0)

The Admin API key is read from ~/.config/claude-widget/api_key.txt
(written there by the widget before calling this script).
"""

import json
import sys
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone, timedelta
from pathlib import Path

BASE_URL     = "https://api.anthropic.com/v1"
API_KEY_FILE = Path.home() / ".config" / "claude-widget" / "api_key.txt"
FALLBACK_EUR = 0.92   # used when exchange-rate fetch fails


# ── Helpers ───────────────────────────────────────────────────────────────────

def load_api_key() -> str:
    if not API_KEY_FILE.exists():
        print(json.dumps({"error":
            f"No API key found. Add your Anthropic Admin API key in the widget settings."}))
        sys.exit(1)
    key = API_KEY_FILE.read_text().strip()
    if not key:
        print(json.dumps({"error": "API key file is empty."}))
        sys.exit(1)
    return key


def get_date_range(window: str):
    now = datetime.now(timezone.utc)
    if window == "daily":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif window == "weekly":
        start = (now - timedelta(days=now.weekday())).replace(
            hour=0, minute=0, second=0, microsecond=0)
    else:                                                        # monthly
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    return start, now


def api_get(url: str, api_key: str, params: dict | None = None) -> dict:
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    req = urllib.request.Request(url)
    req.add_header("x-api-key", api_key)
    req.add_header("anthropic-version", "2023-06-01")
    req.add_header("content-type", "application/json")
    req.add_header("User-Agent", "claude-usage-widget/1.2")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def fetch_eur_rate() -> float:
    try:
        req = urllib.request.Request("https://open.er-api.com/v6/latest/USD")
        req.add_header("User-Agent", "claude-usage-widget/1.2")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read()).get("rates", {}).get("EUR", FALLBACK_EUR)
    except Exception:
        return FALLBACK_EUR


def fmt_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}K"
    return str(n)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    window     = sys.argv[1] if len(sys.argv) > 1 else "monthly"
    currency   = sys.argv[2] if len(sys.argv) > 2 else "EUR"
    budget_cap = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0

    api_key       = load_api_key()
    start, end    = get_date_range(window)
    start_str     = start.strftime("%Y-%m-%dT%H:%M:%SZ")
    end_str       = end.strftime("%Y-%m-%dT%H:%M:%SZ")
    bucket_width  = "1h" if window == "daily" else "1d"
    params        = {"starting_at": start_str, "ending_at": end_str,
                     "bucket_width": bucket_width}

    # ── Token usage ───────────────────────────────────────────────────────────
    input_tokens = output_tokens = 0
    try:
        usage = api_get(f"{BASE_URL}/organizations/usage_report/messages", api_key, params)
        for bucket in usage.get("data", []):
            for r in bucket.get("results", []):
                input_tokens  += r.get("uncached_input_tokens", 0)
                input_tokens  += r.get("cache_read_input_tokens", 0)
                output_tokens += r.get("output_tokens", 0)
    except urllib.error.HTTPError as e:
        msg = (f"API key rejected (HTTP {e.code}). Use an Admin API key."
               if e.code in (401, 403) else f"HTTP {e.code} fetching usage.")
        print(json.dumps({"error": msg}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

    total_tokens = input_tokens + output_tokens

    # ── Cost ──────────────────────────────────────────────────────────────────
    cost_usd = 0.0
    try:
        cost_data = api_get(f"{BASE_URL}/organizations/cost_report", api_key, params)
        for bucket in cost_data.get("data", []):
            for r in bucket.get("results", []):
                cost_usd += float(r.get("amount", 0)) / 100   # cents → dollars
    except Exception:
        pass   # cost display is optional; don't fail the widget over it

    # ── Currency ──────────────────────────────────────────────────────────────
    if currency == "EUR":
        cost   = cost_usd * fetch_eur_rate()
        symbol = "€"
    else:
        cost   = cost_usd
        symbol = "$"

    budget_pct = min((cost / budget_cap * 100) if budget_cap > 0 else 0.0, 100.0)

    print(json.dumps({
        "mode": "api",
        "window": window,
        "tokens": {
            "total":   total_tokens,
            "input":   input_tokens,
            "output":  output_tokens,
            "display": fmt_tokens(total_tokens),
        },
        "cost": {
            "amount":         round(cost, 2),
            "currency":       currency,
            "symbol":         symbol,
            "display":        f"{symbol}{cost:.2f}",
            "budget_display": (f"{symbol}{cost:.2f} / {symbol}{budget_cap:.2f}"
                               if budget_cap > 0 else f"{symbol}{cost:.2f}"),
        },
        "budget": {
            "cap":     budget_cap,
            "pct":     round(budget_pct, 1),
            "has_cap": budget_cap > 0,
        },
    }))


if __name__ == "__main__":
    main()
