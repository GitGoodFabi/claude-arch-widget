import shutil
import subprocess

import pytest


def test_qmllint(widget_root):
    qmllint = shutil.which("qmllint")
    if not qmllint:
        pytest.skip("qmllint is not installed")
    files = [
        widget_root / "contents/ui/main.qml",
        widget_root / "contents/ui/configGeneral.qml",
        widget_root / "contents/config/config.qml",
    ]
    result = subprocess.run([qmllint, *map(str, files)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr or result.stdout
