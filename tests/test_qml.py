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


@pytest.mark.parametrize("height,countdown", [(40, "1h 5m"), (60, "6h 25m"), (80, "167h 59m")])
def test_taskbar_width_fits_text(widget_root, height, countdown, monkeypatch):
    import json

    pytest.importorskip("PySide6.QtGui")
    pytest.importorskip("PySide6.QtQml")
    from PySide6.QtCore import QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlComponent, QQmlEngine

    monkeypatch.setenv("QT_QPA_PLATFORM", "offscreen")
    app = QGuiApplication.instance() or QGuiApplication([])
    source = (widget_root / "contents/ui/main.qml").read_text()
    sizing = source.split("readonly property real iconSize:", 1)[1].split("Layout.minimumWidth:", 1)[0]
    panel = source.split("// ── Horizontal panel: claudeai mode text", 1)[1].split(
        "// ── Horizontal panel: API mode text", 1
    )[0]
    panel = panel[panel.index("Column {"):].replace("Kirigami.Theme.disabledTextColor", '"gray"')
    qml = '''import QtQuick
Item {
    id: root
    property bool compactEnabled: false
    property bool apiMode: false
    property bool loading: false
    property bool hasClaudeUsageData: true
    property string errorMsg: ""
    property real sessionPct: 89
    property real weeklyPct: 22
    property string sessionResetsIn: COUNTDOWN
    property string weeklyResetsIn: COUNTDOWN
    property var theme: ({s: "orange", w: "yellow"})
    property bool panelTextVisible: panelPercentage.visible
    property real measuredWidth: compact.width
    property string displayedPercentage: panelPercentage.text
    property string displayedReset: panelReset.text
    property real textExtent: Math.max(probePercent.implicitWidth, probeReset.implicitWidth)
    property real iconExtent: compactCanvas.x + compactCanvas.width
    Text { id: probePercent; text: "89%"; font.pixelSize: Math.round(HEIGHT * .32); font.bold: true }
    Text { id: probeReset; text: COUNTDOWN; font.pixelSize: Math.round(HEIGHT * .22) }
    Item {
        id: compact
        property bool vertical: false
        property real h: HEIGHT
        readonly property real iconSize: SIZING
        width: totalW
        height: h
        Item { id: compactCanvas; x: Math.round((compact.h - width) / 2); width: compact.iconSize }
        PANEL
    }
}'''.replace("COUNTDOWN", json.dumps(countdown)).replace("HEIGHT", str(height)).replace("SIZING", sizing.replace("Plasmoid.configuration.panelCompactMode", "root.compactEnabled")).replace("PANEL", panel)
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(qml.encode(), QUrl())
    obj = component.create()
    assert obj is not None, [error.toString() for error in component.errors()]
    app.processEvents()
    right_gap = obj.property("measuredWidth") - obj.property("iconExtent") - round(height * .15) - obj.property("textExtent")
    assert round(height * .08) <= right_gap < round(height * .08) + 1

    # Opening the popup starts a refresh; retain both content and width.
    width_before = obj.property("measuredWidth")
    obj.setProperty("loading", True)
    app.processEvents()
    assert obj.property("displayedPercentage") == "89%"
    assert obj.property("displayedReset") == countdown
    assert obj.property("measuredWidth") == width_before
    # Before the first successful fetch, placeholders still indicate loading.
    obj.setProperty("hasClaudeUsageData", False)
    app.processEvents()
    assert obj.property("displayedPercentage") == "…"
    assert obj.property("displayedReset") == ""

    # Rings-only mode occupies one panel-height square and hides all text.
    obj.setProperty("compactEnabled", True)
    app.processEvents()
    assert obj.property("measuredWidth") == height
    assert not obj.property("panelTextVisible")
    obj.setProperty("apiMode", True)
    app.processEvents()
    assert obj.property("measuredWidth") == height
    obj.setProperty("apiMode", False)
    obj.setProperty("loading", False)
    obj.setProperty("hasClaudeUsageData", True)
    obj.setProperty("compactEnabled", False)
    app.processEvents()
    assert obj.property("panelTextVisible")
    assert obj.property("measuredWidth") == width_before


def test_panel_compact_mode_setting_defaults_off(widget_root):
    import xml.etree.ElementTree as ET

    schema = ET.parse(widget_root / "contents/config/main.xml")
    entry = schema.find(".//{*}entry[@name='panelCompactMode']")
    assert entry is not None
    assert entry.attrib["type"] == "Bool"
    assert entry.find("{*}default").text == "false"
    settings = (widget_root / "contents/ui/configGeneral.qml").read_text()
    assert "cfg_panelCompactModeDefault: false" in settings
    assert "cfg_panelCompactMode: panelCompactToggle.checked" in settings
