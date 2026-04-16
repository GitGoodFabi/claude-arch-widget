#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="${REPO_DIR}/.test-venv"
PYTHON_BIN="${PYTHON:-python3}"

cleanup() {
    rm -rf "$VENV_DIR"
}
trap cleanup EXIT

cd "$REPO_DIR"
export PYTHONDONTWRITEBYTECODE=1

"$PYTHON_BIN" -m venv "$VENV_DIR"
# External Python dependency kept intentionally lean: pytest only.
"$VENV_DIR/bin/pip" install --quiet --upgrade pip pytest

pytest_status=0
qml_status=0

"$VENV_DIR/bin/pytest" tests/ -v --tb=short || pytest_status=$?

if command -v qmllint >/dev/null 2>&1; then
    qmllint \
        claude-usage-widget/contents/ui/main.qml \
        claude-usage-widget/contents/ui/configGeneral.qml \
        claude-usage-widget/contents/config/config.qml || qml_status=$?
else
    echo "qmllint not installed; skipping standalone qmllint pass"
fi

if [[ $pytest_status -eq 0 && $qml_status -eq 0 ]]; then
    echo "PASS: test suite and qml checks succeeded"
    exit 0
fi

echo "FAIL: pytest_status=$pytest_status qml_status=$qml_status"
exit 1
