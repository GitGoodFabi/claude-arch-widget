# Changelog

All notable changes to Claude Usage Monitor are documented here.

## [1.6] - 2026-05-04

### Added
- **In-widget update button** for Claude.ai mode: pull the latest git changes from the repo path recorded by `setup.sh`, reinstall the plasmoid files, and restart Plasma without re-running `setup.sh`

### Fixed
- `setup.sh` now fully replaces the installed plasmoid directory before copying files, preventing stale QML/Python files from surviving upgrades
- `setup.sh` now restarts Plasma more reliably on KDE 6 / SteamOS by preferring `kstart6`, falling back to `kstart`, then `plasmashell --replace`
- `setup.sh` now records the local clone path automatically, so the widget no longer asks users for a manual repository path
- Settings page is now scrollable, so options remain reachable on small screens, high DPI, or large font scaling
- Settings dropdowns now force readable text/highlight colors in dark Plasma themes

## [1.5] - 2026-05-04

### Added
- **Extract from browser** button in widget settings (Claude.ai mode): re-reads the `sessionKey` cookie from Firefox/Chromium/Brave/Edge and saves it without leaving the settings dialog. No more re-running `setup.sh` to refresh an expired session.
- `extract_cookie.py` is now bundled inside the plasmoid package so the button works out of the box.

### Fixed
- Expired session keys now surface as `"Session key has expired — open widget settings and click 'Extract from browser'"` instead of the cryptic JSON parse error `"Expecting value: line 1 column 1 (char 0)"`.
- Auth-error helper text now points users at the new in-widget button instead of `setup.sh`.

## [1.4] - 2026-04-16

### Added
- **Per-model breakdown** in API view: top 3 models by token volume with individual spend and percentage
- **Prompt cache stats** in API view: cache read tokens and cache efficiency percentage
- **Daily average and projected monthly spend** in API view
- **"All time" window** for API mode (last 365 days)
- **Budget mode toggle**: show cap countdown for the selected window or hide it entirely
- **API ring display mode**: choose whether the ring fills for remaining budget or used spend
- **Follow Plasma theme**: widget auto-switches color theme based on KDE dark/light mode
- **Separate light/dark theme pair**: set one theme for light mode and another for dark, applied automatically
- **Sync settings between instances**: `syncSettingsByMode` keeps multiple widgets on the same desktop in sync
- **Extended refresh intervals**: 30 minutes, 1 hour, 2 hours, and 6 hours — useful for API mode to avoid rate limits
- **API result cache** (`api_cache.py`): widget shows last good data immediately on open while a fresh fetch runs in background

### Fixed
- Admin API key validation now caches the result locally — the `/organizations/me` round-trip is skipped on every refresh after the first, cutting API calls per tick from 3 to 2 and reducing 429 rate-limit exposure

## [1.3] - 2026-04-14

### Added
- Anthropic API mode is now live and working with organization Admin API keys
- API usage view now shows token breakdown, model spend, daily average, projected spend, and prompt caching info
- Manual cap countdown can be shown for the selected API window or disabled entirely

### Changed
- API mode now treats the manual cap in the selected display currency instead of implicitly converting a USD cap
- API mode enforces a safer minimum refresh interval to reduce Anthropic Admin API rate limiting
- API settings and error messages now explain that the feature requires an organization Admin API key
- Widget/store metadata and documentation now highlight API mode as a shipped feature

### Fixed
- Admin API key validation now accepts current Anthropic Admin key prefixes like `sk-ant-admin01-...`
- API errors now surface the real script/backend message instead of collapsing to generic `Script failed`
- API detail view is scrollable and keeps previous values visible during refresh, avoiding empty/overlapping states in smaller popups
- Manual cap ring rendering is restored when cap countdown is enabled
- API mode now handles Anthropic `HTTP 429` responses with a clearer rate-limit message

## [1.2] - 2026-04-12

### Fixed
- Widget no longer freezes on loading state when the backend script crashes or returns non-JSON output
- Notifications no longer re-fire for already-crossed thresholds on every plasmashell restart
- Notification message body ("Resets in …") is now properly translated via i18n
- Shell argument escaping in `notify-send` call prevents breakage if reset time contains special characters
- `tempfile.mktemp()` (deprecated, TOCTOU race) replaced with `tempfile.mkstemp()` in cookie extractor
- Fallback error string was German ("Script fehlgeschlagen") — now uses i18n

### Changed
- Header title changed from "Claude Pro" to "Claude" (accurate for all plan tiers)
- Session legend label updated to "Session (5h)" to clarify it is a 5-hour rolling window
- All German inline comments in QML source translated to English
- Widget name updated to "Claude Usage Monitor" for clarity

### Added
- Configurable script path in settings (for non-default installation locations)
- `notify-send` and `python3` dependency check in `setup.sh` with actionable error messages
- `BugReportUrl` and `Tags` added to widget metadata for KDE Store discoverability

## [1.1] - 2025-12-01

### Added
- Sidebar shortcuts panel with icons for New Chat, Projects, Usage, Claude CLI, VS Code
- Desktop shortcuts toggle (show/hide quick-launch buttons below rings)
- Custom color theme via KDE color picker

### Changed
- Amber theme renamed to "Amber (Claude)"

## [1.0] - 2025-11-01

### Added
- Initial release
- Dual-ring display: session (5h) and weekly usage
- Color themes: Amber, Ocean, Aurora, Violet, Liquid Glass, Emerald, Rose
- Usage notifications at 25%, 50%, 80%, 95% thresholds for session and weekly
- Compact panel representation with ring + percentage
- Full desktop representation with legend and reset times
- Minimal view mode (rings only)
- Auto-refresh timer with configurable interval
- Custom project shortcut
- Widget and background opacity controls
