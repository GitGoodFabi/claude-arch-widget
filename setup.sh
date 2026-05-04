#!/usr/bin/env bash
# Claude Usage Widget — Setup Script
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/claude-widget"
SCRIPT_DST="$CONFIG_DIR/claude_usage.py"
REPO_PATH_FILE="$CONFIG_DIR/repo_path.txt"
PLASMOID_ID="com.github.fabian.claude-usage"
PLASMOID_DST="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▸ $*${NC}"; }
ok()    { echo -e "  ${GREEN}✓ $*${NC}"; }
warn()  { echo -e "  ${YELLOW}⚠ $*${NC}"; }
err()   { echo -e "  ${RED}✗ $*${NC}"; }
prompt(){ echo -en "  ${BOLD}$*${NC} "; }

echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║    Claude Usage Widget  —  Setup    ║"
echo -e "╚══════════════════════════════════════╝${NC}"

# ── 0. Dependency checks ──────────────────────────────────────────────────────
step "Checking dependencies..."
MISSING=0
for cmd in python3 notify-send; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd found"
    else
        err "$cmd not found"
        MISSING=1
    fi
done
if [ "$MISSING" = "1" ]; then
    echo ""
    warn "Install missing dependencies before continuing."
    warn "  notify-send is provided by: libnotify (Arch: pacman -S libnotify)"
    exit 1
fi

# ── 1. Config directory ───────────────────────────────────────────────────────
step "Creating config directory..."
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
ok "Config dir: $CONFIG_DIR"

# ── 2. Install fetch script ───────────────────────────────────────────────────
step "Installing fetch script..."
cp "$REPO_DIR/claude_usage.py" "$SCRIPT_DST"
chmod 755 "$SCRIPT_DST"
ok "Script installed: $SCRIPT_DST"

step "Recording local repo path..."
printf '%s\n' "$REPO_DIR" > "$REPO_PATH_FILE"
chmod 600 "$REPO_PATH_FILE"
ok "Repo path stored: $REPO_PATH_FILE"

# ── 3. Session key ────────────────────────────────────────────────────────────
step "Setting up session key..."

if [ -f "$CONFIG_DIR/session.txt" ] && [ -s "$CONFIG_DIR/session.txt" ]; then
    warn "Session key already exists at $CONFIG_DIR/session.txt"
    prompt "Re-use it? [Y/n]:"
    read -r REUSE
    if [[ "${REUSE:-Y}" =~ ^[Yy]$ ]]; then
        ok "Using existing session key."
        HAVE_KEY=1
    fi
fi

if [ "${HAVE_KEY:-0}" = "0" ]; then
    echo -e "  Trying to extract session key from your browser..."
    SESSION_KEY="$(python3 "$REPO_DIR/extract_cookie.py" 2>/dev/tty)" || SESSION_KEY=""

    if [ -n "$SESSION_KEY" ]; then
        echo "$SESSION_KEY" > "$CONFIG_DIR/session.txt"
        chmod 600 "$CONFIG_DIR/session.txt"
        ok "Session key extracted from browser automatically."
    else
        warn "Could not auto-extract. Please paste it manually."
        echo ""
        echo -e "  ${BOLD}How to get your session key:${NC}"
        echo "  1. Open https://claude.ai in your browser and log in"
        echo ""
        echo -e "  ${BOLD}Firefox:${NC}"
        echo "  2. Press F12 → Storage tab → Cookies → https://claude.ai"
        echo "  3. Find the row named  sessionKey  and copy its Value"
        echo ""
        echo -e "  ${BOLD}Chrome / Chromium / Brave / Edge:${NC}"
        echo "  2. Press F12 → Application tab → Cookies → https://claude.ai"
        echo "  3. Find the row named  sessionKey  and copy its Value"
        echo ""
        prompt "Paste sessionKey here:"
        read -r SESSION_KEY
        if [ -z "$SESSION_KEY" ]; then
            err "No session key provided. Aborting."
            exit 1
        fi
        echo "$SESSION_KEY" > "$CONFIG_DIR/session.txt"
        chmod 600 "$CONFIG_DIR/session.txt"
        ok "Session key saved."
    fi
fi

# ── 4. Test data fetch ────────────────────────────────────────────────────────
step "Testing data fetch..."
OUTPUT="$(python3 "$SCRIPT_DST" 2>&1)"

if python3 -c "import sys,json; d=json.loads(sys.stdin.read()); exit(0 if 'session' in d else 1)" <<< "$OUTPUT" 2>/dev/null; then
    ok "Data fetch successful!"
    echo "$OUTPUT" | python3 -m json.tool 2>/dev/null || echo "$OUTPUT"
else
    err "Fetch failed."
    echo "  Response: $OUTPUT"
    echo ""
    warn "Your session key might be expired or wrong."
    warn "Delete $CONFIG_DIR/session.txt and re-run setup.sh to try again."
    exit 1
fi

# ── 5. Install widget ─────────────────────────────────────────────────────────
step "Installing Plasma widget..."
rm -rf "$PLASMOID_DST"
mkdir -p "$PLASMOID_DST"
cp -r "$REPO_DIR/claude-usage-widget/." "$PLASMOID_DST/"
ok "Widget installed: $PLASMOID_DST"

# ── 5b. Install icon into system icon theme ───────────────────────────────────
step "Installing widget icon..."
ICON_DST="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DST"
cp "$REPO_DIR/claude-usage-widget/contents/icons/claude-usage.svg" "$ICON_DST/claude-usage.svg"
kbuildsycoca6 2>/dev/null || true
ok "Icon installed and cache rebuilt"

# ── 6. Restart Plasma ─────────────────────────────────────────────────────────
step "Restarting Plasma shell..."
if kquitapp6 plasmashell 2>/dev/null; then
    sleep 1
    if command -v kstart6 &>/dev/null; then
        kstart6 plasmashell &>/dev/null &
    elif command -v kstart &>/dev/null; then
        kstart plasmashell &>/dev/null &
    else
        plasmashell --replace &>/dev/null &
    fi
    ok "Plasma shell restarting in background."
else
    warn "Could not restart plasmashell automatically."
    warn "Please log out and back in, or run:  kquitapp6 plasmashell && kstart6 plasmashell"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║          Setup complete!             ║"
echo -e "╚══════════════════════════════════════╝${NC}"
echo -e "  Right-click your panel or desktop"
echo -e "  → ${BOLD}Add Widgets${NC} → search for ${BOLD}Claude Usage${NC}"
echo ""
echo -e "  ${YELLOW}Session key expires when you log out of claude.ai."
echo -e "  Re-run setup.sh to refresh it.${NC}"
echo ""
