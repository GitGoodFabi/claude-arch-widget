# KDE Store Listing — Claude Usage Monitor

## Short tagline (max ~80 chars)
Because "why did Claude stop responding" is not a great debugging strategy.

---

## Full description (paste into store.kde.org "Description" field)

You know that moment mid-flow when Claude just… stops? Turns out you burned
through your session limit 20 minutes ago and had absolutely no idea. Cool
feature. Very useful. 10/10.

**Claude Usage Monitor** fixes that. It sits in your panel, on your desktop,
or in your sidebar and shows your session (5-hour rolling window) and weekly
usage as two live rings — so you can see the wall coming before you run into
it face-first.

**Looks good doing it too**

7 built-in color themes — Amber (Claude's own orange), Ocean, Aurora, Violet,
Liquid Glass, Emerald, and Rose — plus a full custom color picker if none of
those match your rice. Opacity controls for both the widget and background,
because your setup matters.

**Lives wherever you put it**

- **Panel** — compact ring + percentage, fits any taskbar
- **Sidebar** — vertical mode with all four stats inside the ring
- **Desktop** — full popup with rings, legend, reset times, and shortcuts

**Shortcuts, because clicking is work**

One click to New Chat, Projects, your Usage page, Claude CLI in a terminal,
VS Code, or your own custom project link. You configure the terminal — konsole,
kitty, foot, WezTerm, whatever you run.

**Notifications that actually matter**

Optional desktop alerts when you hit 25 %, 50 %, 80 %, or 95 % — separately
for session and weekly. Enable only what you care about, ignore the rest.
Notifications don't re-fire on plasmashell restart either, because that would
be annoying and we thought about it.

**Requirements**

- KDE Plasma 6
- Python 3
- `libnotify` (`notify-send`) — for notifications
- A claude.ai account (Pro or Max)

**Installation**

1. Install via Discover or the KDE Widget Store
2. Run `setup.sh` once — auto-extracts your session cookie from Firefox or
   Chromium, or lets you paste it manually if you enjoy doing things the hard way
3. Add the widget to your panel or desktop

Session key expired? Re-run `setup.sh`. The widget will tell you when it
happens and point you at the fix — no detective work required.

**Source & bugs**

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
