# Claude Usage Widget

A KDE Plasma 6 widget for Linux that shows your **Claude Pro session and weekly usage** at a glance — directly in your panel, sidebar, or on the desktop.

![Widget Preview](https://github.com/GitGoodFabi/claude-arch-widget/blob/main/claude-usage-widget/contents/screenshots/Standard%20Widget.png)

## Features

- **Compact panel view** — two concentric rings showing session (5h window) and weekly usage, plus time until next reset
- **Sidebar view** — three modes: compact (ring + shortcuts), full widget (scales to sidebar width), or ring only
- **Full desktop/popup view** — detailed rings with legend, exact percentages and reset times
- **Quick links** — New Chat, Projects, Usage page, custom project shortcut
- **App shortcuts** — open Claude CLI in your terminal or reopen VS Code
- **Auto-refresh** — configurable interval (5 s – 10 min), or manual
- **Minimal ring-only mode** — for desktop use; click the ring to open a shortcut menu
- **Anthropic API mode** — track token usage and cost against your API budget
- **i18n** — English, German, French, Spanish

## Requirements

- KDE Plasma 6
- Python 3
- A Claude Pro or Anthropic API account
- `libsecret` — optional, for automatic cookie extraction from Chrome/Brave/Edge on KDE (`sudo pacman -S libsecret`)

## Installation

```bash
git clone https://github.com/GitGoodFabi/claude-arch-widget.git
cd claude-arch-widget
bash setup.sh
```

`setup.sh` will:
1. **Auto-extract** your `sessionKey` cookie from Firefox or Chrome/Chromium — no manual copy-paste needed in most cases
2. Test the data fetch against the claude.ai API
3. Install the Plasma widget
4. Restart Plasma shell

Then: right-click your panel or desktop → **Add Widgets** → search for **Claude Usage**.

> **Tip:** Firefox users get fully automatic setup. Chrome/Chromium/Brave users also work automatically if `libsecret` is installed — it reads the key from KWallet on your behalf.

## Getting your session key manually

If auto-extraction fails:

1. Open [claude.ai](https://claude.ai) in your browser and make sure you're logged in
2. Open DevTools (`F12`):
   - **Firefox:** Storage tab → Cookies → `https://claude.ai`
   - **Chrome / Brave / Edge:** Application tab → Cookies → `https://claude.ai`
3. Copy the value of the `sessionKey` cookie
4. Paste it when `setup.sh` asks

The key is stored at `~/.config/claude-widget/session.txt` (chmod 600) and never leaves your machine.

> **Session keys expire** when you log out of claude.ai. Re-run `setup.sh` to refresh.

## Configuration

Right-click the widget → **Configure**:

| Option | Default | Description |
|---|---|---|
| View (Desktop) | off | Minimal ring-only view for desktop; click ring for shortcuts |
| Sidebar view | Compact | **Compact** (ring + shortcuts), **Full widget** (scales to sidebar width), or **Ring only** |
| Desktop shortcuts | on | Show quick-link buttons below rings in desktop/popup view |
| Background opacity | 0% | Transparency of the dark background (desktop view) |
| Terminal app | `konsole` | Used for the "Claude CLI" button (`kitty`, `alacritty`, `foot`, …) |
| Auto-refresh | on | Enable/disable the background refresh timer |
| Interval | 5 min | Refresh interval (5 s / 30 s / 2 min / 5 min / 10 min) |
| Project shortcut | — | Name + URL of a Claude project; adds a button to the popup |

## How it works

`claude_usage.py` authenticates against the claude.ai API using your session cookie and fetches usage data from `/api/organizations/{id}/usage`. The widget calls this script on a configurable timer and parses the JSON output. No data is sent anywhere except to claude.ai.

## Security

- Session key stored with `chmod 600`, never committed to git
- Only outbound requests to `claude.ai` — no telemetry, no third-party services
- Script runs locally; widget sandbox via KDE Plasma DataSource engine

## License

MIT
