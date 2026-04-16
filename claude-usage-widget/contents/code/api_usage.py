#!/usr/bin/env python3
"""Fetches Anthropic API token usage and cost data for the Plasma widget.

Usage: python3 api_usage.py [window] [currency] [budget_cap] [budget_mode]
  window     : daily | weekly | monthly | all  (default: monthly)
  currency   : EUR | USD                 (default: EUR)
  budget_cap : float, 0 = no cap        (default: 0)
  budget_mode: selected | none          (default: selected)

The Admin API key is read from ~/.config/claude-widget/api_key.txt
(written there by the widget before calling this script).

Output JSON schema:
  mode, window, tokens.{total,input,output,cache_read,cache_write,*_display},
  cost.{display,budget_display,saved_display,daily_avg_display,projected_display},
  budget.{pct,has_cap,cap},
  cache_efficiency (int 0-100),
  by_model [{display, tokens_display, cost_display, pct}]
"""

import json
import sys
import urllib.request
import urllib.parse
import urllib.error
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone, timedelta
from pathlib import Path

BASE_URL     = "https://api.anthropic.com/v1"
API_KEY_FILE      = Path.home() / ".config" / "claude-widget" / "api_key.txt"
_KEY_VALIDATED_FILE = Path.home() / ".config" / "claude-widget" / ".key_validated"
FALLBACK_EUR = 0.92   # used when live rate fetch fails

# ── Model pricing (USD per million tokens) ────────────────────────────────────
# (input, output, cache_read, cache_write)
# Matched by longest prefix against the model ID string.
_PRICING = [
    ("claude-opus-4-6",         5.00, 25.00, 0.500,  6.250),
    ("claude-opus-4-5",         5.00, 25.00, 0.500,  6.250),
    ("claude-opus-4-1",        15.00, 75.00, 1.500, 18.750),
    ("claude-opus-4",          15.00, 75.00, 1.500, 18.750),
    ("claude-sonnet-4-6",       3.00, 15.00, 0.300,  3.750),
    ("claude-sonnet-4-5",       3.00, 15.00, 0.300,  3.750),
    ("claude-sonnet-4",         3.00, 15.00, 0.300,  3.750),
    ("claude-haiku-4-5",        1.00,  5.00, 0.100,  1.250),
    ("claude-3-7-sonnet",       3.00, 15.00, 0.300,  3.750),
    ("claude-3-5-sonnet",       3.00, 15.00, 0.300,  3.750),
    ("claude-3-5-haiku",        0.80,  4.00, 0.080,  1.000),
    ("claude-3-opus",          15.00, 75.00, 1.500, 18.750),
    ("claude-3-sonnet",         3.00, 15.00, 0.300,  3.750),
    ("claude-3-haiku",          0.25,  1.25, 0.030,  0.300),
]
_DEFAULT_PRICING = (3.00, 15.00, 0.300, 3.750)  # Sonnet as safe fallback

def _price(model_id: str) -> tuple:
    m = model_id.lower()
    for row in _PRICING:
        if row[0] in m:
            return row[1:]
    return _DEFAULT_PRICING

def _token_cost_usd(inp: int, out: int, cr: int, cw: int, model_id: str) -> float:
    p = _price(model_id)
    M = 1_000_000
    return (inp * p[0] + out * p[1] + cr * p[2] + cw * p[3]) / M

def _model_label(model_id: str) -> str:
    m = model_id.lower()
    if "opus-4-6"   in m: return "Opus 4.6"
    if "opus-4-5"   in m: return "Opus 4.5"
    if "opus-4-1"   in m: return "Opus 4.1"
    if "opus-4"     in m: return "Opus 4"
    if "sonnet-4-6" in m: return "Sonnet 4.6"
    if "sonnet-4-5" in m: return "Sonnet 4.5"
    if "sonnet-4"   in m: return "Sonnet 4"
    if "haiku-4-5"  in m: return "Haiku 4.5"
    if "3-7-sonnet" in m: return "Sonnet 3.7"
    if "3-5-sonnet" in m: return "Sonnet 3.5"
    if "3-5-haiku"  in m: return "Haiku 3.5"
    if "3-opus"     in m: return "Opus 3"
    if "3-sonnet"   in m: return "Sonnet 3"
    if "3-haiku"    in m: return "Haiku 3"
    # Truncate unknown names
    return model_id[:16]


# ── I/O helpers ──────────────────────────────────────────────────────────────

def _load_key() -> str:
    if not API_KEY_FILE.exists():
        _fail("No API key configured. Add your Anthropic Admin API key in widget settings.")
    key = API_KEY_FILE.read_text().strip()
    if not key:
        _fail("API key file is empty.")
    return key

def _validate_admin_key(key: str):
    if not key.startswith("sk-ant-admin"):
        _fail("This widget's API mode requires an Anthropic Admin API key (sk-ant-admin...), not a standard API key.")

    # Skip the network round-trip if we already validated this exact key.
    import hashlib
    key_hash = hashlib.sha256(key.encode()).hexdigest()
    if _KEY_VALIDATED_FILE.exists() and _KEY_VALIDATED_FILE.read_text().strip() == key_hash:
        return

    try:
        org = _api_get("/organizations/me", key)
    except urllib.error.HTTPError as e:
        auth = e.code in (401, 403)
        if auth:
            _KEY_VALIDATED_FILE.unlink(missing_ok=True)
            _fail(
                "Anthropic rejected this Admin API key, or the account has no organization access. "
                "The Usage & Cost Admin API only works for organizations, not individual accounts.",
                True,
            )
        _fail(f"HTTP {e.code} validating organization access.")
    except Exception as e:
        _fail(f"Could not validate organization access: {e}")

    if not isinstance(org, dict) or not org.get("id"):
        _fail("Anthropic did not return organization details for this Admin API key.")

    # Stamp the hash so subsequent refreshes skip this call.
    _KEY_VALIDATED_FILE.parent.mkdir(parents=True, exist_ok=True)
    _KEY_VALIDATED_FILE.write_text(key_hash)

def _fail(msg: str, auth: bool = False):
    print(json.dumps({"error": msg, "auth": auth}))
    sys.exit(1)

def _api_get(path: str, key: str, params: dict | None = None) -> dict:
    url = f"{BASE_URL}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    req = urllib.request.Request(url)
    req.add_header("x-api-key", key)
    req.add_header("anthropic-version", "2023-06-01")
    req.add_header("User-Agent", "claude-usage-widget/1.3")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def _api_get_all(path: str, key: str, params: dict | None = None) -> list[dict]:
    """Fetch all paginated buckets from an Admin API report endpoint."""
    page_params = dict(params or {})
    buckets: list[dict] = []

    while True:
        payload = _api_get(path, key, page_params)
        buckets.extend(payload.get("data", []))
        next_page = payload.get("next_page")
        if not payload.get("has_more") or not next_page:
            break
        page_params["page"] = next_page

    return buckets

def _eur_rate() -> float:
    try:
        req = urllib.request.Request("https://open.er-api.com/v6/latest/USD")
        req.add_header("User-Agent", "claude-usage-widget/1.3")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read()).get("rates", {}).get("EUR", FALLBACK_EUR)
    except Exception:
        return FALLBACK_EUR

def _fmt_tok(n: int) -> str:
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000:     return f"{n/1_000:.0f}K"
    return str(n)

def _fmt_cost(usd: float, sym: str) -> str:
    if usd <= 0:
        return f"{sym}0.00"
    if usd < 0.01:
        return f"{sym}{usd:.4f}"
    if usd < 1:
        return f"{sym}{usd:.3f}"
    return f"{sym}{usd:.2f}"

def _as_int(value) -> int:
    if value in (None, ""):
        return 0
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value)
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return 0

def _as_amount(value) -> float:
    if value in (None, ""):
        return 0.0
    try:
        return float(Decimal(str(value)))
    except (InvalidOperation, ValueError):
        return 0.0

def _sum_cache_creation(value) -> int:
    if isinstance(value, dict):
        return sum(_as_int(v) for v in value.values())
    if isinstance(value, list):
        return sum(_sum_cache_creation(v) for v in value)
    return _as_int(value)

def _bucket_results(bucket: dict) -> list[dict]:
    results = bucket.get("results")
    if isinstance(results, list):
        return [r for r in results if isinstance(r, dict)]
    if isinstance(results, dict):
        return [results]
    # Some Admin API responses aggregate directly at the bucket level when
    # there is no grouping or when the schema shifts slightly.
    if any(k in bucket for k in (
        "model",
        "uncached_input_tokens",
        "input_tokens",
        "cache_read_input_tokens",
        "cache_creation_input_tokens",
        "output_tokens",
    )):
        return [bucket]
    return []


# ── Date range ────────────────────────────────────────────────────────────────

def _date_range(window: str):
    now   = datetime.now(timezone.utc)
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    if window == "daily":
        start = today
        days_total   = 1
        days_elapsed = 1
    elif window == "weekly":
        start        = today - timedelta(days=today.weekday())
        days_total   = 7
        days_elapsed = max(1, today.weekday() + 1)
    elif window == "all":
        start        = today - timedelta(days=365)
        days_total   = 365
        days_elapsed = 365
    else:  # monthly
        start        = today.replace(day=1)
        import calendar
        days_total   = calendar.monthrange(today.year, today.month)[1]
        days_elapsed = max(1, today.day)
    return start, now, days_total, days_elapsed


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    window     = sys.argv[1] if len(sys.argv) > 1 else "monthly"
    currency   = sys.argv[2] if len(sys.argv) > 2 else "EUR"
    try:
        budget_cap = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    except ValueError:
        budget_cap = 0.0
    budget_mode = sys.argv[4] if len(sys.argv) > 4 else "selected"
    if budget_mode not in ("selected", "none"):
        budget_mode = "selected"

    key = _load_key()
    _validate_admin_key(key)
    start, end, days_total, days_elapsed = _date_range(window)

    bucket_width = "1h" if window == "daily" else "1d"
    params = {
        "starting_at":  start.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "ending_at":    end.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "bucket_width": bucket_width,
        "group_by[]":   ["model"],
    }

    # ── Fetch token usage ─────────────────────────────────────────────────────
    # Aggregate totals and per-model breakdown
    tot_input = tot_output = tot_cache_read = tot_cache_write = 0
    by_model: dict[str, dict] = {}   # model_id → {inp, out, cr, cw}

    try:
        usage_buckets = _api_get_all("/organizations/usage_report/messages", key, params)
    except urllib.error.HTTPError as e:
        auth = e.code in (401, 403)
        if e.code == 429:
            _fail("Anthropic rate-limited the Usage & Cost Admin API (HTTP 429). Increase the widget refresh interval and try again.")
        _fail(f"API key rejected (HTTP {e.code}). Use an Admin API key." if auth
              else f"HTTP {e.code} fetching usage.", auth)
    except Exception as e:
        _fail(str(e))

    saw_usage_rows = False
    for bucket in usage_buckets:
        for r in _bucket_results(bucket):
            saw_usage_rows = True
            model = r.get("model", "unknown")
            inp   = _as_int(r.get("uncached_input_tokens", r.get("input_tokens", 0)))
            cr    = _as_int(r.get("cache_read_input_tokens", 0))
            cache_creation = r.get("cache_creation") or {}
            if isinstance(cache_creation, dict):
                cw = _sum_cache_creation(cache_creation)
            else:
                cw = _sum_cache_creation(cache_creation)
            if cw == 0:
                cw = _as_int(r.get("cache_creation_input_tokens", 0))
            out   = _as_int(r.get("output_tokens", 0))

            tot_input       += inp
            tot_output      += out
            tot_cache_read  += cr
            tot_cache_write += cw

            if model not in by_model:
                by_model[model] = {"inp": 0, "out": 0, "cr": 0, "cw": 0}
            by_model[model]["inp"] += inp
            by_model[model]["out"] += out
            by_model[model]["cr"]  += cr
            by_model[model]["cw"]  += cw

    total_tokens = tot_input + tot_output + tot_cache_read + tot_cache_write

    # ── Compute cost per model using pricing table ────────────────────────────
    # Also try the official cost_report endpoint; use it if available.
    cost_usd_total = 0.0
    model_cost_usd: dict[str, float] = {}
    for mid, t in by_model.items():
        c = _token_cost_usd(t["inp"], t["out"], t["cr"], t["cw"], mid)
        model_cost_usd[mid] = c
        cost_usd_total += c

    # Override with official cost data if the endpoint responds
    try:
        cost_params = dict(params)
        cost_params["bucket_width"] = "1d"
        cost_buckets = _api_get_all("/organizations/cost_report", key, cost_params)
        official_total = 0.0
        saw_cost_rows = False
        for bucket in cost_buckets:
            for r in _bucket_results(bucket):
                saw_cost_rows = True
                official_total += _as_amount(r.get("amount", 0)) / 100  # cents → USD
        if official_total > 0:
            cost_usd_total = official_total
    except Exception:
        saw_cost_rows = False
        pass  # fall back to pricing-table cost — it's close enough

    # ── Cache metrics ─────────────────────────────────────────────────────────
    effective_input   = tot_input + tot_cache_read
    cache_efficiency  = int(tot_cache_read / effective_input * 100) if effective_input > 0 else 0

    # Money saved: what cache_read tokens would have cost at full input rate
    saved_usd = 0.0
    for mid, t in by_model.items():
        p = _price(mid)
        saved_usd += t["cr"] * (p[0] - p[2]) / 1_000_000

    # ── Currency conversion ───────────────────────────────────────────────────
    if currency == "EUR":
        rate = _eur_rate()
        sym  = "€"
    else:
        rate = 1.0
        sym  = "$"

    def _c(usd: float) -> str:
        return _fmt_cost(usd * rate, sym)

    # ── Daily avg + projection ────────────────────────────────────────────────
    daily_avg_usd  = cost_usd_total / days_elapsed
    projected_usd  = daily_avg_usd  * days_total

    # ── Budget ────────────────────────────────────────────────────────────────
    has_cap       = budget_cap > 0
    cost_local    = cost_usd_total * rate
    cap_local     = budget_cap if has_cap else 0.0
    remaining_local = max(0.0, cap_local - cost_local) if has_cap else 0.0
    budget_pct    = min(cost_local / cap_local * 100, 100.0) if has_cap and cap_local > 0 else 0.0

    # ── Per-model display (top 3 by token volume) ─────────────────────────────
    top_models = sorted(
        by_model.items(),
        key=lambda item: item[1]["inp"] + item[1]["out"] + item[1]["cr"] + item[1]["cw"],
        reverse=True,
    )[:3]
    by_model_display = []
    for mid, t in top_models:
        cost = model_cost_usd.get(mid, 0.0)
        tok = t["inp"] + t["out"] + t["cr"] + t["cw"]
        pct = int(cost / cost_usd_total * 100) if cost_usd_total > 0 else 0
        by_model_display.append({
            "display":       _model_label(mid),
            "tokens_display": _fmt_tok(tok),
            "cost_display":   _c(cost),
            "pct":            pct,
        })

    empty_usage = not saw_usage_rows and total_tokens == 0
    fallback_mode = empty_usage

    tokens_display = _fmt_tok(total_tokens) if not fallback_mode else "—"
    input_display = _fmt_tok(tot_input) if not fallback_mode else "—"
    output_display = _fmt_tok(tot_output) if not fallback_mode else "—"
    cache_read_display = _fmt_tok(tot_cache_read) if not fallback_mode else "—"
    cache_write_display = _fmt_tok(tot_cache_write) if not fallback_mode else "—"
    cost_display = _c(cost_usd_total) if (cost_usd_total > 0 or saw_cost_rows) else "—"
    budget_display = (
        f"{_c(cost_usd_total)} / {_fmt_cost(cap_local, sym)}" if has_cap and (cost_usd_total > 0 or saw_cost_rows)
        else (_fmt_cost(cap_local, sym) if has_cap and fallback_mode else cost_display)
    )

    # ── Output ────────────────────────────────────────────────────────────────
    print(json.dumps({
        "mode":   "api",
        "window": window,
        "empty":  empty_usage,
        "fallback": fallback_mode,
        "message": (
            "No message usage rows returned by Anthropic for this time window."
            if fallback_mode else
            ""
        ),
        "tokens": {
            "total":              total_tokens,
            "display":            tokens_display,
            "input":              tot_input,
            "input_display":      input_display,
            "output":             tot_output,
            "output_display":     output_display,
            "cache_read":         tot_cache_read,
            "cache_read_display": cache_read_display,
            "cache_write":        tot_cache_write,
            "cache_write_display": cache_write_display,
        },
        "cost": {
            "amount":              round(cost_local, 2),
            "currency":            currency,
            "symbol":              sym,
            "display":             cost_display,
            "budget_display":      budget_display,
            "saved_display":       (_c(saved_usd) + " saved" if not fallback_mode and saved_usd > 0 else ""),
            "remaining_display":   (_fmt_cost(remaining_local, sym) + " left" if has_cap else ""),
            "daily_avg_display":   (_c(daily_avg_usd) + "/day" if (cost_usd_total > 0 or saw_cost_rows) else "—"),
            "projected_display":   (_c(projected_usd) if (cost_usd_total > 0 or saw_cost_rows) else "—"),
        },
        "budget": {
            "cap":     budget_cap,
            "mode":    budget_mode,
            "pct":     round(budget_pct, 1),
            "has_cap": has_cap,
        },
        "cache_efficiency": cache_efficiency,
        "by_model":         by_model_display,
    }))


if __name__ == "__main__":
    main()
