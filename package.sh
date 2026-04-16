#!/usr/bin/env bash
# Packages the Claude Usage Monitor widget into a .plasmoid file for KDE Store upload.
set -euo pipefail

WIDGET_DIR="claude-usage-widget"
METADATA="$WIDGET_DIR/metadata.json"
OUTPUT="com.github.fabian.claude-usage.plasmoid"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
step() { echo -e "\n${CYAN}${BOLD}▸ $*${NC}"; }
ok()   { echo -e "  ${GREEN}✓ $*${NC}"; }
err()  { echo -e "  ${RED}✗ $*${NC}"; exit 1; }

cd "$(dirname "$0")"

step "Validating metadata.json..."
python3 -c "
import json, sys
with open('$METADATA') as f:
    m = json.load(f)
p = m.get('KPlugin', {})
required = ['Name', 'Id', 'Version', 'License', 'Description']
missing = [k for k in required if not p.get(k)]
if missing:
    print('Missing fields: ' + ', '.join(missing))
    sys.exit(1)
print('  Name:    ' + p['Name'])
print('  Id:      ' + p['Id'])
print('  Version: ' + p['Version'])
" || err "metadata.json validation failed"
ok "metadata.json valid"

step "Checking required files..."
for f in \
    "$WIDGET_DIR/contents/ui/main.qml" \
    "$WIDGET_DIR/contents/ui/configGeneral.qml" \
    "$WIDGET_DIR/contents/config/main.xml" \
    "$WIDGET_DIR/contents/config/config.qml" \
    "$WIDGET_DIR/contents/code/claude_usage.py" \
    "$WIDGET_DIR/contents/icons/claude-usage.svg"; do
    [ -f "$f" ] && ok "$f" || err "Missing: $f"
done

step "Building $OUTPUT..."
rm -f "$OUTPUT"
cd "$WIDGET_DIR"
zip -r "../$OUTPUT" . \
    --exclude "*.pyc" \
    --exclude "__pycache__/*" \
    --exclude "*/__pycache__/*" \
    --exclude "__pycache__" \
    --exclude "*/__pycache__" \
    --exclude ".DS_Store" \
    -q
cd ..
ok "Created: $OUTPUT ($(du -sh "$OUTPUT" | cut -f1))"

echo -e "\n${GREEN}${BOLD}Ready to upload to https://store.kde.org${NC}"
echo -e "  File: ${BOLD}$OUTPUT${NC}"
