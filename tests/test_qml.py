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


@pytest.mark.parametrize("theme,rgb,alphas", [
    ("amber", (255, 115, 0), (1, 1, .18, .18, .65, .65, .5)),
    ("ocean", (59, 158, 255), (1, 1, .18, .18, .6, .6, .5)),
    ("aurora", (0, 212, 170), (1, 1, .18, .18, .6, .6, .5)),
    ("violet", (168, 85, 247), (1, 1, .18, .18, .6, .6, .5)),
    ("glass", (210, 235, 255), (.92, .78, .13, .09, .55, .45, .45)),
    ("emerald", (16, 185, 129), (1, 1, .18, .18, .6, .6, .5)),
    ("rose", (244, 63, 94), (1, 1, .18, .18, .6, .6, .5)),
])
def test_preset_colors_bind_to_qml_color_properties(widget_root, theme, rgb, alphas, monkeypatch):
    """Exercise Qt's actual color conversion, including translucent labels."""
    pytest.importorskip("PySide6.QtGui")
    pytest.importorskip("PySide6.QtQml")
    from PySide6.QtCore import QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlComponent, QQmlEngine

    monkeypatch.setenv("QT_QPA_PLATFORM", "offscreen")
    app = QGuiApplication.instance() or QGuiApplication([])
    source = (widget_root / "contents/ui/main.qml").read_text()
    palette = source.split("        var map = {", 1)[1].split('        return map[key] || map["amber"]', 1)[0]
    fields = ("s", "w", "sT", "wT", "sDim", "wDim", "sLbl")
    bindings = "\n".join(f"property color {field}: palette.{field}" for field in fields)
    qml = ('import QtQuick\nQtObject {\nproperty var palette: {\nvar map = {'
           + palette + f'\nreturn map["{theme}"]\n}}\n' + bindings + '\n}')
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(qml.encode(), QUrl())
    obj = component.create()
    assert obj is not None, [error.toString() for error in component.errors()]
    for field, alpha in zip(fields, alphas):
        color = obj.property(field)
        assert color.isValid(), (theme, field)
        assert color.alphaF() == pytest.approx(alpha, abs=1 / 255), (theme, field)
    label = obj.property("sLbl")
    assert (label.red(), label.green(), label.blue()) == rgb
    # Keep the application alive until the QML objects have been checked.
    assert app is not None


@pytest.mark.parametrize("weekly,session,session_reset,loading,error,expected", [
    (99.9, 25, "2h 10m", False, "", ("25%", "2h 10m", "orange")),
    (100, 0, "?", False, "", ("100%", "10h 21m", "yellow")),
    (100, 100, "1h 5m", False, "", ("100%", "10h 21m", "yellow")),
    (101, 0, "?", False, "", ("101%", "10h 21m", "yellow")),
    (100, 0, "?", True, "", ("…", "", "yellow")),
    (100, 0, "?", False, "Network error", ("!", "", "#ff5555")),
])
def test_taskbar_prioritizes_exhausted_weekly_limit(
    widget_root, weekly, session, session_reset, loading, error, expected, monkeypatch
):
    import json
    import re

    pytest.importorskip("PySide6.QtGui")
    pytest.importorskip("PySide6.QtQml")
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QJSEngine

    monkeypatch.setenv("QT_QPA_PLATFORM", "offscreen")
    app = QGuiApplication.instance() or QGuiApplication([])
    source = (widget_root / "contents/ui/main.qml").read_text()
    panel = source.split("// ── Horizontal panel: claudeai mode text", 1)[1].split(
        "// ── Horizontal panel: API mode text", 1
    )[0]
    texts = re.findall(r"^\s*text: (.+)$", panel, re.MULTILINE)
    color = re.search(r"^\s*color: (.+)$", panel, re.MULTILINE).group(1)
    engine = QJSEngine()
    engine.evaluate("var root = " + json.dumps({
        "weeklyPct": weekly, "sessionPct": session,
        "sessionResetsIn": session_reset, "weeklyResetsIn": "10h 21m",
        "loading": loading, "errorMsg": error,
        "theme": {"s": "orange", "w": "yellow"},
    }))
    assert len(texts) == 2
    actual = []
    for expression in [*texts, color]:
        result = engine.evaluate(expression)
        assert not result.isError(), result.toString()
        actual.append(result.toString())
    assert tuple(actual) == expected
    assert app is not None
