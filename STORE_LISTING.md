# KDE Store Listing: Claude Usage Monitor

## Short tagline (max ~80 chars)
Live Claude usage for KDE: claude.ai limits plus Anthropic API spend.

---

## Full description (paste into store.kde.org "Description" field)

This is my first publicly released piece of software. Thought you should know
that upfront.

It started simple: I wanted a widget that shows my Claude usage in the panel.
The existing ones didn't quite do what I wanted, so I figured: how hard can
it be. Several rabbit holes later, it's fully themeable, runs in panels,
sidebars, and on the desktop, has a minimal ring-only mode, shortcut buttons,
desktop notifications at configurable thresholds, and now a live API mode for
Anthropic organization usage and spend. Classic.

A fair amount of this was coded with Claude's help. I'm aware of how that
sounds given what the widget does. I tried to keep resource usage sensible
and avoid obvious security holes. I'm a beginner writing for people who
almost certainly are not, so go easy on me.

I know this is roughly widget number 2011 in the "Claude usage for KDE"
category. I like mine. Maybe you will too.

**What it actually does**

Shows your Claude session (5-hour rolling window) and weekly usage as two
live rings in your panel, sidebar, or on the desktop, so you can see the wall
coming before you run into it face-first.

It also has an API mode: live Anthropic organization usage, token totals,
cost, per-model breakdown, prompt caching stats, daily average, projections,
and an optional local cap countdown. Multiple widget instances sync their
settings automatically, and the color theme can follow KDE's dark/light mode.

**Wherever you put it**

- **Panel** - compact rings + percentage, fits any taskbar
- **Sidebar** - vertical mode with all four stats inside the rings
- **Desktop** - full popup with rings, legend, reset times, and shortcuts
- **Minimal mode** - rings only, click to open shortcuts

**Looks decent too**

7 built-in color themes (Amber, Ocean, Aurora, Violet, Liquid Glass, Emerald,
Rose) plus a full custom color picker. Opacity controls for background and
widget, because your rice matters.

**Shortcuts**

One click to New Chat, Projects, your Usage page, Claude CLI in a terminal,
VS Code, or a custom project link. You pick the terminal.

**Notifications**

Optional alerts at 25 %, 50 %, 80 %, 95 %, separately for session and
weekly. They don't re-fire on plasmashell restart either, because that would
be unreasonable.

**Requirements**

- KDE Plasma 6
- Python 3
- `libnotify` (`notify-send`) for notifications
- A claude.ai account (Pro or Max), or an Anthropic organization Admin API key for API mode

**Installation**

```
git clone https://github.com/GitGoodFabi/claude-arch-widget.git
cd claude-arch-widget
bash setup.sh
```

`setup.sh` auto-extracts your session cookie from Firefox or Chromium, tests
the connection, installs the widget, and restarts Plasma. Session key expired?
Re-run `setup.sh`.

**Bugs**

If you find any, please open an issue. I genuinely want to know and will do
my best to fix them. I hope this brings some small amount of joy to at least a
few people.

**Source**

https://github.com/GitGoodFabi/claude-arch-widget

---

## Version history (for store changelog field)

**1.4**
- Per-model breakdown in API view (top 3 by token volume with spend and %)
- Prompt cache efficiency stats in API view
- Daily average and projected monthly spend in API view
- "All time" window for API mode (last 365 days)
- Budget mode: show cap countdown for selected window or disable it
- API ring display: fill for remaining budget or used spend
- Follow Plasma theme: auto-switch color theme in KDE dark/light mode
- Light/dark theme pair: set separate themes per Plasma appearance
- Sync settings between widget instances automatically
- Extended refresh intervals: 30 min, 1 h, 2 h, 6 h
- API result cache: shows previous data immediately while refresh runs in background
- Admin key validation cached — reduces API calls per refresh and HTTP 429 exposure

**1.3**
- API mode is now live for Anthropic organization Admin API keys
- API widget shows token totals, spend, model breakdown, prompt caching, daily average, and projection
- Manual cap countdown can be shown for the selected API window or disabled
- Admin key validation fixed for current Anthropic key prefixes
- API refresh behavior hardened against rate limiting
- API errors now surface real backend messages instead of generic failures
- API popup layout fixed to avoid overlapping content in smaller widget sizes

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
