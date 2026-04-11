# Changelog

All notable changes to Claude Usage Monitor are documented here.

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
