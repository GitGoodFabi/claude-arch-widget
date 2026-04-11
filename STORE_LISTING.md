# KDE Store Listing — Claude Usage Monitor

## Short tagline (max ~80 chars)
Monitor your Claude AI usage limits directly from KDE Plasma.

---

## Full description (paste into store.kde.org "Description" field)

**Claude Usage Monitor** shows your Claude AI session and weekly usage as live
dual-ring gauges in your KDE Plasma panel, desktop, or sidebar — so you always
know how much of your limit you have left without opening a browser.

**Features**

- **Dual rings** — inner ring shows the 5-hour rolling session window, outer
  ring shows the 7-day weekly window
- **7 color themes** — Amber (Claude), Ocean, Aurora, Violet, Liquid Glass,
  Emerald, Rose — plus a fully custom color picker
- **Usage notifications** — optional desktop alerts at 25 %, 50 %, 80 %, and
  95 % for both session and weekly limits
- **Three layout modes** — horizontal panel, vertical sidebar, and full desktop
  widget with legend and reset times
- **Quick-launch shortcuts** — New Chat, Projects, Usage page, Claude CLI, VS
  Code, and a configurable custom project link
- **Auto-refresh** — configurable interval from 5 seconds to 10 minutes
- **Minimal view** — rings-only mode for tight spaces
- **Opacity controls** — independently tune widget and background opacity

**Requirements**

- KDE Plasma 6
- Python 3
- `libnotify` (`notify-send`) — for desktop notifications
- A claude.ai account (Pro or Max)

**Installation**

1. Install the widget via Discover or the KDE Widget Store
2. Clone or download the repository and run `setup.sh` once — this extracts
   your `sessionKey` cookie from Firefox or Chromium automatically, or lets
   you paste it manually
3. Add the widget to your panel or desktop

The session key refreshes whenever you log into claude.ai. If the widget shows
"Session key expired", re-run `setup.sh` or paste a fresh key.

**Source & bug reports**

https://github.com/GitGoodFabi/claude-arch-widget

---

## Version history (for store changelog field)

**1.2**
- Widget is now self-contained: Python script bundled inside the plasmoid
- Session key expiry shows a helpful error with a setup guide button
- Custom SVG icon replacing generic "brain" icon
- Notification flood on plasmashell restart fixed (first-load flag)
- Loading freeze on script crash fixed
- Shell injection in notify-send fixed
- "Resets in" notification text now translated
- All German source comments translated to English
- Header renamed from "Claude Pro" to "Claude"
- Session legend clarified to "Session (5h)"
- Configurable script path added to settings
- notify-send dependency check added to setup.sh
- Packaging script (package.sh) added

**1.1**
- Sidebar shortcuts (New Chat, Projects, Usage, Claude CLI, VS Code)
- Desktop shortcuts toggle
- Custom color theme via KDE color picker
- Amber theme renamed to "Amber (Claude)"

**1.0**
- Initial release
