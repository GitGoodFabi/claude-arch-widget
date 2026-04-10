import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property real sessionPct: 0
    property real weeklyPct: 0
    property string sessionResetsIn: "?"
    property string weeklyResetsIn: "?"
    property string sessionResetsAt: ""
    property string weeklyResetsAt: ""
    property string errorMsg: ""
    property bool loading: true

    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation

    Component.onCompleted: fetchData()
    onExpandedChanged: { if (expanded) fetchData() }

    // ── Compact (Panel) ───────────────────────────────────────────────────
    compactRepresentation: Item {
        Layout.minimumWidth: compactRow.implicitWidth + 8
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }

        Row {
            id: compactRow
            anchors.centerIn: parent
            spacing: 5

            Canvas {
                id: compactCanvas
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width/2, cy = height/2
                    arc(ctx, cx, cy, 9.5, 3, 1.0,                  "rgba(255,179,71,0.18)")
                    arc(ctx, cx, cy, 9.5, 3, root.weeklyPct/100,   "#FFB347")
                    arc(ctx, cx, cy, 5.5, 3, 1.0,                  "rgba(255,115,0,0.18)")
                    arc(ctx, cx, cy, 5.5, 3, root.sessionPct/100,  "#FF7300")
                }
                function arc(ctx, cx, cy, r, lw, frac, color) {
                    ctx.beginPath()
                    if      (frac >= 1.0) ctx.arc(cx,cy,r, 0, 2*Math.PI)
                    else if (frac >  0)   ctx.arc(cx,cy,r, -Math.PI/2, -Math.PI/2 + 2*Math.PI*frac)
                    else return
                    ctx.strokeStyle = color; ctx.lineWidth = lw
                    ctx.lineCap = frac >= 1.0 ? "butt" : "round"
                    ctx.stroke()
                }
                Connections {
                    target: root
                    function onSessionPctChanged() { compactCanvas.requestPaint() }
                    function onWeeklyPctChanged()  { compactCanvas.requestPaint() }
                    function onLoadingChanged()    { compactCanvas.requestPaint() }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: root.loading ? "…" : root.errorMsg ? "!" : Math.round(root.sessionPct) + "%"
                    color: root.errorMsg ? "#ff5555" : "#FF7300"
                    font.pixelSize: 10; font.bold: true
                }
                Text {
                    text: root.loading || root.errorMsg ? "" : root.sessionResetsIn
                    color: Kirigami.Theme.disabledTextColor; font.pixelSize: 8
                }
            }
        }
    }

    // ── Full (Desktop & Popup) ────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullView

        Layout.minimumWidth:   Plasmoid.configuration.minimalView ? 120 : 220
        Layout.minimumHeight:  Plasmoid.configuration.minimalView ? 120 : 300
        Layout.preferredWidth: Plasmoid.configuration.minimalView ? 160 : (onDesktop ? 340 : 280)
        Layout.fillWidth:      true
        Layout.fillHeight:     true

        readonly property bool minimal: Plasmoid.configuration.minimalView
        readonly property real pad:     16
        readonly property real headerH: 36
        readonly property real buttonsH: hasProjectShortcut ? 100 : 70
        readonly property bool hasProjectShortcut:
            Plasmoid.configuration.projectShortcutLabel !== "" &&
            Plasmoid.configuration.projectShortcutUrl   !== ""

        readonly property real availH: height - headerH - buttonsH - pad * 3
        readonly property real ringDiam: minimal
            ? Math.max(80, Math.min(width, height) - pad)
            : Math.max(80, Math.min(width - pad * 2, availH - 80))

        // Eigener Hintergrund
        Rectangle {
            anchors.fill: parent
            radius: root.onDesktop ? 12 : 0
            color: "#1e1e22"
            opacity: Plasmoid.configuration.backgroundOpacity
        }

        // ── Header ──
        Item {
            id: header
            visible: !fullView.minimal
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: fullView.pad }
            height: fullView.headerH

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Claude Pro"
                color: "white"; font.bold: true
                font.pixelSize: Math.max(13, fullView.ringDiam * 0.09)
            }
            PlasmaComponents.ToolButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                icon.name: "view-refresh"
                opacity: root.loading ? 0.3 : 0.6
                onClicked: fetchData()
                PlasmaComponents.ToolTip { text: i18n("Refresh") }
            }
        }

        // ── Fehler ──
        Text {
            visible: root.errorMsg !== ""
            anchors { top: header.bottom; left: parent.left; right: parent.right; margins: fullView.pad }
            text: root.errorMsg; color: "#ff5555"; wrapMode: Text.Wrap
            font.pixelSize: Math.max(10, fullView.ringDiam * 0.07)
        }

        // ── Ringe ──
        Canvas {
            id: ringCanvas
            visible: root.errorMsg === ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: fullView.minimal ? parent.top : header.bottom
            anchors.topMargin: fullView.minimal ? (parent.height - fullView.ringDiam) / 2 : fullView.pad / 2
            width:  fullView.ringDiam
            height: fullView.ringDiam

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width/2, cy = height/2
                var lw = Math.max(5, width * 0.068)
                ring(ctx, cx, cy, width*0.43, lw, root.weeklyPct,  "#FFB347", "rgba(255,179,71,0.12)")
                ring(ctx, cx, cy, width*0.31, lw, root.sessionPct, "#FF7300", "rgba(255,115,0,0.12)")
            }
            function ring(ctx, cx, cy, r, lw, pct, color, track) {
                ctx.beginPath(); ctx.arc(cx,cy,r,0,2*Math.PI)
                ctx.strokeStyle=track; ctx.lineWidth=lw; ctx.lineCap="butt"; ctx.stroke()
                var f = Math.min(Math.max(pct,0),100)/100
                if (f<=0) return
                ctx.beginPath(); ctx.arc(cx,cy,r,-Math.PI/2,-Math.PI/2+2*Math.PI*f)
                ctx.strokeStyle=color; ctx.lineWidth=lw; ctx.lineCap="round"; ctx.stroke()
            }
            Connections {
                target: root
                function onSessionPctChanged() { ringCanvas.requestPaint() }
                function onWeeklyPctChanged()  { ringCanvas.requestPaint() }
                function onLoadingChanged()    { ringCanvas.requestPaint() }
            }
            onWidthChanged: requestPaint()

            Column {
                anchors.centerIn: parent; spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loading ? "…" : Math.round(root.sessionPct) + "%"
                    color: "#FF7300"
                    font.pixelSize: Math.max(12, ringCanvas.width * 0.13)
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n("SESSION")
                    color: Qt.rgba(1,0.44,0,0.5)
                    font.pixelSize: Math.max(6, ringCanvas.width * 0.046)
                    font.letterSpacing: 1.5
                }
            }
        }

        // ── Legende ──
        Column {
            id: legend
            visible: root.errorMsg === "" && !fullView.minimal
            anchors { bottom: buttons.top; left: parent.left; right: parent.right
                      margins: fullView.pad; bottomMargin: 8 }
            spacing: 4

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }
            Item { width: 1; height: 2 }

            Row {
                width: parent.width; spacing: 6
                Rectangle { width:8; height:8; radius:4; color:"#FF7300"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: i18n("Session"); color:"white"; font.pixelSize:11; width:55 }
                Text { text:Math.round(root.sessionPct)+"%"; color:"#FF7300"; font.pixelSize:11; font.bold:true; width:34 }
                Text { text:"↻ "+root.sessionResetsIn; color:Qt.rgba(1,1,1,0.4); font.pixelSize:10; anchors.verticalCenter:parent.verticalCenter }
            }
            Text {
                visible: root.sessionResetsAt !== ""
                leftPadding: 14
                text: i18n("Reset at %1", Qt.formatTime(new Date(root.sessionResetsAt), "hh:mm"))
                color: Qt.rgba(1,1,1,0.28); font.pixelSize: 9
            }
            Row {
                width: parent.width; spacing: 6
                Rectangle { width:8; height:8; radius:4; color:"#FFB347"; anchors.verticalCenter:parent.verticalCenter }
                Text { text: i18n("Week"); color:"white"; font.pixelSize:11; width:55 }
                Text { text:Math.round(root.weeklyPct)+"%"; color:"#FFB347"; font.pixelSize:11; font.bold:true; width:34 }
                Text { text:"↻ "+root.weeklyResetsIn; color:Qt.rgba(1,1,1,0.4); font.pixelSize:10; anchors.verticalCenter:parent.verticalCenter }
            }
            Text {
                visible: root.weeklyResetsAt !== ""
                leftPadding: 14
                text: i18n("Reset on %1 at %2",
                    Qt.formatDate(new Date(root.weeklyResetsAt), "dddd"),
                    Qt.formatTime(new Date(root.weeklyResetsAt), "hh:mm"))
                color: Qt.rgba(1,1,1,0.28); font.pixelSize: 9
            }
        }

        // ── Schnelllinks ──
        Column {
            id: buttons
            visible: !fullView.minimal
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                      margins: fullView.pad; bottomMargin: fullView.pad }
            spacing: 5

            Row {
                width: parent.width; spacing: 5
                Repeater {
                    model: [
                        { label: i18n("New Chat"), icon: "list-add",                 url: "https://claude.ai/new"            },
                        { label: i18n("Projects"), icon: "folder",                   url: "https://claude.ai/projects"       },
                        { label: i18n("Usage"),    icon: "utilities-system-monitor", url: "https://claude.ai/settings/usage" }
                    ]
                    PlasmaComponents.Button {
                        width: (buttons.width - 10) / 3
                        text: modelData.label; icon.name: modelData.icon; font.pixelSize: 10
                        onClicked: { Qt.openUrlExternally(modelData.url); root.expanded = false }
                    }
                }
            }

            Row {
                width: parent.width; spacing: 5

                PlasmaComponents.Button {
                    width: (buttons.width - 5) / 2
                    text: "Claude CLI"
                    icon.name: "utilities-terminal"
                    font.pixelSize: 10
                    onClicked: {
                        var term = Plasmoid.configuration.terminalApp.trim() || "konsole"
                        var cmd
                        if (term === "konsole")
                            cmd = "konsole --noclose -e claude"
                        else if (term === "gnome-terminal" || term === "xfce4-terminal")
                            cmd = term + " -- claude"
                        else if (term === "kitty" || term === "foot" || term === "wezterm")
                            cmd = term + " claude"
                        else
                            cmd = term + " -e claude"
                        executable.connectSource(cmd)
                        root.expanded = false
                    }
                    PlasmaComponents.ToolTip { text: i18n("Open Claude Code in terminal") }
                }

                PlasmaComponents.Button {
                    width: (buttons.width - 5) / 2
                    text: "VS Code"
                    icon.name: "vscode"
                    font.pixelSize: 10
                    onClicked: {
                        executable.connectSource("code --reuse-window")
                        root.expanded = false
                    }
                    PlasmaComponents.ToolTip { text: i18n("Open last VS Code window") }
                }
            }

            Row {
                width: parent.width
                visible: fullView.hasProjectShortcut

                PlasmaComponents.Button {
                    width: parent.width
                    text: Plasmoid.configuration.projectShortcutLabel
                    icon.name: "folder-open"
                    font.pixelSize: 10
                    onClicked: {
                        Qt.openUrlExternally(Plasmoid.configuration.projectShortcutUrl)
                        root.expanded = false
                    }
                    PlasmaComponents.ToolTip { text: Plasmoid.configuration.projectShortcutUrl }
                }
            }
        }
    }

    // ── Datenabruf ────────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            if (!out.startsWith("{")) return
            root.loading = false
            if (data["exit code"] !== 0) {
                root.errorMsg = (data["stderr"] || "Script fehlgeschlagen").trim()
                return
            }
            try {
                var j = JSON.parse(out)
                if (j.error) { root.errorMsg = j.error; return }
                root.errorMsg        = ""
                root.sessionPct      = j.session.utilization
                root.sessionResetsIn = j.session.resets_in
                root.sessionResetsAt = j.session.resets_at
                root.weeklyPct       = j.weekly.utilization
                root.weeklyResetsIn  = j.weekly.resets_in
                root.weeklyResetsAt  = j.weekly.resets_at
            } catch(e) {
                root.errorMsg = "Parse-Fehler: " + e
            }
        }
    }

    function fetchData() {
        root.loading = true
        root.errorMsg = ""
        executable.connectSource("python3 \"$HOME/Claude Arch Widget/claude_usage.py\"")
    }

    Timer {
        interval: Math.max(5, Plasmoid.configuration.refreshIntervalSeconds) * 1000
        running: Plasmoid.configuration.timerEnabled
        repeat: true
        onTriggered: fetchData()
    }
}
