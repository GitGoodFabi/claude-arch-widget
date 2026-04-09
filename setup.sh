#!/usr/bin/env bash
set -e

WIDGET_DIR="$(cd "$(dirname "$0")" && pwd)/claude-usage-widget"
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/claude_usage.py"
SCRIPT_DST="$HOME/Claude Arch Widget/claude_usage.py"
CONFIG_DIR="$HOME/.config/claude-widget"

echo "=== Claude Usage Widget Setup ==="
echo ""

# 1. Session key
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/session.txt" ] || [ ! -s "$CONFIG_DIR/session.txt" ]; then
    echo "Paste your claude.ai sessionKey cookie value (from DevTools → Cookies):"
    echo -n "> "
    read -r SESSION_KEY
    echo "$SESSION_KEY" > "$CONFIG_DIR/session.txt"
    chmod 600 "$CONFIG_DIR/session.txt"
    echo "Session key saved to $CONFIG_DIR/session.txt"
else
    echo "Session key already exists at $CONFIG_DIR/session.txt"
fi

# 2. Test the script
echo ""
echo "Testing data fetch..."
OUTPUT=$(python3 "$SCRIPT_SRC" 2>&1)
echo "$OUTPUT" | python3 -m json.tool 2>/dev/null || echo "$OUTPUT"

# 3. Install widget
echo ""
echo "Installing Plasma widget..."
plasmapkg2 --install "$WIDGET_DIR" 2>/dev/null || \
    plasmapkg2 --upgrade "$WIDGET_DIR" 2>/dev/null || \
    kpackagetool6 --install "$WIDGET_DIR" 2>/dev/null || \
    kpackagetool6 --upgrade "$WIDGET_DIR" 2>/dev/null || \
    { echo "ERROR: Could not install widget. Try manually:"; echo "  kpackagetool6 --install '$WIDGET_DIR'"; exit 1; }

echo ""
echo "=== Done! ==="
echo "Right-click your desktop or panel → Add Widgets → search for 'Claude Usage'"
