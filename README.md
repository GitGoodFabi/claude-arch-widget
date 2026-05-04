# Claude Usage Widget

A KDE Plasma 6 widget for Linux that shows your **Claude usage at a glance** — from claude.ai session limits to live Anthropic API usage and spend — directly in your panel, sidebar, or on the desktop.

![Widget Preview](https://github.com/GitGoodFabi/claude-arch-widget/blob/main/claude-usage-widget/contents/screenshots/Standard%20Widget.png)

## Features

- **Compact panel view** — two concentric rings showing session (5h window) and weekly usage, plus time until next reset
- **Sidebar view** — three modes: compact (ring + shortcuts), full widget (scales to sidebar width), or ring only
- **Full desktop/popup view** — detailed rings with legend, exact percentages and reset times
- **Quick links** — New Chat, Projects, Usage page, custom project shortcut
- **App shortcuts** — open Claude CLI in your terminal or reopen VS Code
- **Auto-refresh** — configurable interval (5 s – 10 min), or manual
- **Minimal ring-only mode** — for desktop use; click the ring to open a shortcut menu
- **Anthropic API mode** — live organization token usage, spend, per-model breakdown, cache stats, daily average, projected spend, and optional manual cap countdown
- **Follow Plasma theme** — auto-switch color theme based on KDE dark/light mode
- **Sync settings between instances** — multiple widgets on the same desktop stay in sync
- **i18n** — English, German, French, Spanish

## Requirements

- KDE Plasma 6
- Python 3
- A Claude Pro account, or an Anthropic organization with an Admin API key for API mode
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
3. Install the Plasma widget and fully replace stale files from older versions
4. Record the local git clone path for in-widget updates
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

## Updating

Terminal update:

```bash
git pull --ff-only
bash setup.sh
```

After one successful `setup.sh` run, the widget also gets an in-settings **Pull & install latest** button in Claude.ai mode. It uses the repo path recorded during setup, so there is no manual repository-path field to maintain.

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
| Interval | 5 min | Refresh interval (2 min / 5 min / 10 min / 30 min / 1 h / 2 h / 6 h). API mode minimum is 2 minutes. Longer intervals reduce rate-limit exposure. |
| Project shortcut | — | Name + URL of a Claude project; adds a button to the popup |

The settings page is scrollable, so all options remain reachable on smaller screens, Steam Deck, or higher font scaling.

### API mode notes

- Requires an Anthropic **organization Admin API key**
- Uses Anthropic's **Usage & Cost Admin API**
- Supports daily, weekly, monthly, and all-time (365-day) windows
- Manual cap is local to the widget and is **not** your Anthropic Console spend limit
- Shows per-model breakdown (top 3 by token volume), cache efficiency, daily average, and projected spend
- Admin key is validated once and cached — subsequent refreshes skip the extra round-trip
- Longer refresh intervals (30 min+) are recommended if you hit HTTP 429 rate limits

## How it works

`claude_usage.py` authenticates against the claude.ai API using your session cookie and fetches usage data from `/api/organizations/{id}/usage`. The widget calls this script on a configurable timer and parses the JSON output. No data is sent anywhere except to claude.ai.

API mode uses Anthropic's Usage & Cost Admin API. That requires an organization Admin API key (`sk-ant-admin...`) and does not work for individual accounts. The optional cap ring is a local manual cap, not your Anthropic Console spend limit.

## Security

- Session key stored with `chmod 600`, never committed to git
- API key stored locally for the widget in `~/.config/claude-widget/api_key.txt`, never committed to git
- Only outbound requests to `claude.ai` — no telemetry, no third-party services
- Script runs locally; widget sandbox via KDE Plasma DataSource engine

## License

MIT
