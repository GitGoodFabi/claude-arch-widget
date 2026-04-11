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

    // Verhindert wiederholte Notifications bei gleichem Refresh
    property bool _ns80: false
    property bool _ns95: false
    property bool _nw80: false
    property bool _nw95: false

    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar

    // ── Farbthemen ────────────────────────────────────────────────────────────
    readonly property var theme: {
        var key = Plasmoid.configuration.colorTheme || "amber"
        var map = {
            "amber": {
                s: "#FF7300",              w: "#FFB347",
                sT: "rgba(255,115,0,0.18)",  wT: "rgba(255,179,71,0.18)",
                sDim: "rgba(255,115,0,0.65)",  wDim: "rgba(255,178,71,0.65)",
                sLbl: "rgba(255,115,0,0.5)"
            },
            "ocean": {
                s: "#3B9EFF",              w: "#93C5FD",
                sT: "rgba(59,158,255,0.18)", wT: "rgba(147,197,253,0.18)",
                sDim: "rgba(59,158,255,0.6)", wDim: "rgba(147,197,253,0.6)",
                sLbl: "rgba(59,158,255,0.5)"
            },
            "aurora": {
                s: "#00D4AA",              w: "#67E8F9",
                sT: "rgba(0,212,170,0.18)",  wT: "rgba(103,232,249,0.18)",
                sDim: "rgba(0,212,170,0.6)", wDim: "rgba(103,232,249,0.6)",
                sLbl: "rgba(0,212,170,0.5)"
            },
            "violet": {
                s: "#A855F7",              w: "#E879F9",
                sT: "rgba(168,85,247,0.18)", wT: "rgba(232,121,249,0.18)",
                sDim: "rgba(168,85,247,0.6)",wDim: "rgba(232,121,249,0.6)",
                sLbl: "rgba(168,85,247,0.5)"
            },
            "glass": {
                s: "rgba(210,235,255,0.92)", w: "rgba(255,255,255,0.78)",
                sT: "rgba(210,235,255,0.13)", wT: "rgba(255,255,255,0.09)",
                sDim: "rgba(210,235,255,0.55)", wDim: "rgba(255,255,255,0.45)",
                sLbl: "rgba(210,235,255,0.45)"
            }
        }
        return map[key] || map["amber"]
    }
    onThemeChanged: { compactCanvas.requestPaint(); ringCanvas.requestPaint() }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation

    Component.onCompleted: fetchData()
    onExpandedChanged: { if (expanded) fetchData() }

    function terminalCmd() {
        var term = Plasmoid.configuration.terminalApp.trim() || "konsole"
        // Login-Shell (-l) damit ~/.local/bin im PATH ist; exec bash hält Terminal offen
        if (term === "konsole")
            return "konsole --noclose -e bash -lc 'claude; exec bash'"
        if (term === "gnome-terminal" || term === "xfce4-terminal")
            return term + " -- bash -lc 'claude; exec bash'"
        if (term === "kitty" || term === "foot")
            return term + " bash -lc 'claude; exec bash'"
        if (term === "wezterm")
            return "wezterm start bash -lc 'claude; exec bash'"
        return term + " -e bash -lc 'claude; exec bash'"
    }

    // ── Compact (Panel + Sidebar) ─────────────────────────────────────────
    compactRepresentation: Item {
        id: compact
        opacity: Plasmoid.configuration.widgetOpacity

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        // h = kurze Seite des Panels (Höhe horizontal, Breite vertikal)
        readonly property real h:       vertical ? parent.width : parent.height
        readonly property real iconSize: Math.round(h * 0.84)
        readonly property real textW:   Math.round(h * 1.6)
        readonly property real totalW:  iconSize + textW + Math.round(h * 0.25)

        Layout.minimumWidth:   vertical ? parent.width : totalW
        Layout.preferredWidth: vertical ? parent.width : totalW
        Layout.minimumHeight:  vertical ? iconSize + Math.round(h * 0.08) : parent.height
        Layout.fillHeight:     !vertical
        Layout.fillWidth:      vertical

        MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }

        // ── Ring-Canvas ───────────────────────────────────────────────────
        Canvas {
            id: compactCanvas
            width:  compact.iconSize
            height: compact.iconSize

            // Sidebar: oben zentriert; Horizontal: links, zentriert
            anchors.horizontalCenter: compact.vertical ? parent.horizontalCenter : undefined
            anchors.verticalCenter:   compact.vertical ? undefined               : parent.verticalCenter
            anchors.top:              compact.vertical ? parent.top              : undefined
            anchors.topMargin:        compact.vertical ? Math.round((parent.width - compact.iconSize) / 2) : 0
            anchors.left:             compact.vertical ? undefined               : parent.left
            anchors.leftMargin:       compact.vertical ? 0                       : Math.round((parent.height - compact.iconSize) / 2)

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2, cy = height / 2
                var lw = Math.max(2, width * 0.08)
                arc(ctx, cx, cy, width * 0.44, lw, 1.0,                   root.theme.wT)
                arc(ctx, cx, cy, width * 0.44, lw, root.weeklyPct  / 100, root.theme.w)
                arc(ctx, cx, cy, width * 0.33, lw, 1.0,                   root.theme.sT)
                arc(ctx, cx, cy, width * 0.33, lw, root.sessionPct / 100, root.theme.s)
            }
            function arc(ctx, cx, cy, r, lw, frac, color) {
                ctx.beginPath()
                if      (frac >= 1.0) ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                else if (frac >  0)   ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * frac)
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
            onWidthChanged: requestPaint()

            // Sidebar: alle 4 Werte in die Ringmitte (FixedHeight = kein Standard-Leading)
            Column {
                visible: compact.vertical
                anchors.centerIn: parent
                spacing: 0

                readonly property real bigPx:   Math.max(8,  compactCanvas.width * 0.11)
                readonly property real smallPx: Math.max(6,  compactCanvas.width * 0.08)
                readonly property real gapH:    Math.max(1,  compactCanvas.width * 0.015)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loading ? "…" : root.errorMsg ? "!" : Math.round(root.sessionPct) + "%"
                    color: root.errorMsg ? "#ff5555" : root.theme.s
                    font.pixelSize: parent.bigPx
                    font.bold: true
                    lineHeightMode: Text.FixedHeight
                    lineHeight: parent.bigPx * 1.15
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loading || root.errorMsg ? "" : root.sessionResetsIn
                    color: root.theme.sDim
                    font.pixelSize: parent.smallPx
                    font.weight: Font.Medium
                    lineHeightMode: Text.FixedHeight
                    lineHeight: parent.smallPx * 1.15
                }
                Item { width: 1; height: parent.gapH }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loading || root.errorMsg ? "" : Math.round(root.weeklyPct) + "%"
                    color: root.theme.w
                    font.pixelSize: parent.bigPx
                    font.bold: true
                    lineHeightMode: Text.FixedHeight
                    lineHeight: parent.bigPx * 1.15
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loading || root.errorMsg ? "" : root.weeklyResetsIn
                    color: root.theme.wDim
                    font.pixelSize: parent.smallPx
                    font.weight: Font.Medium
                    lineHeightMode: Text.FixedHeight
                    lineHeight: parent.smallPx * 1.15
                }
            }
        }

        // Horizontal-Panel: Text rechts neben dem Ring
        Column {
            visible: !compact.vertical
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           compactCanvas.right
            anchors.leftMargin:     Math.round(compact.h * 0.15)
            spacing: 0

            Text {
                width: compact.textW
                text: root.loading ? "…" : root.errorMsg ? "!" : Math.round(root.sessionPct) + "%"
                color: root.errorMsg ? "#ff5555" : root.theme.s
                font.pixelSize: Math.round(compact.h * 0.32)
                font.bold: true
            }
            Text {
                width: compact.textW
                text: root.loading || root.errorMsg ? "" : root.sessionResetsIn
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Math.round(compact.h * 0.22)
            }
        }

        // Sidebar-Shortcuts (optional, Icon-Buttons unter dem Ring)
        Column {
            visible: compact.vertical && Plasmoid.configuration.sidebarShortcuts
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:              compactCanvas.bottom
            anchors.topMargin:        Math.round(compact.h * 0.08)
            spacing:                  Math.round(compact.h * 0.05)

            Repeater {
                model: {
                    var items = [
                        { icon: "list-add",                 url: "https://claude.ai/new",            tip: i18n("New Chat") },
                        { icon: "utilities-system-monitor", url: "https://claude.ai/settings/usage", tip: i18n("Usage")    }
                    ]
                    if (Plasmoid.configuration.projectShortcutLabel !== "" && Plasmoid.configuration.projectShortcutUrl !== "")
                        items.push({ icon: "folder-open", url: Plasmoid.configuration.projectShortcutUrl, tip: Plasmoid.configuration.projectShortcutLabel })
                    return items
                }
                PlasmaComponents.ToolButton {
                    width:  Math.round(compact.h * 0.55)
                    height: Math.round(compact.h * 0.55)
                    icon.name: modelData.icon
                    onClicked: Qt.openUrlExternally(modelData.url)
                    PlasmaComponents.ToolTip { text: modelData.tip }
                }
            }
        }
    }

    // ── Full (Desktop & Popup) ────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullView
        opacity: Plasmoid.configuration.widgetOpacity

        Layout.minimumWidth:   Plasmoid.configuration.minimalView ? 120 : 220
        Layout.minimumHeight:  Plasmoid.configuration.minimalView ? 120 : 300
        Layout.preferredWidth: Plasmoid.configuration.minimalView ? 180 : (onDesktop ? 340 : 280)
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
            ? Math.max(80, Math.min(width, height) - pad * 2)
            : Math.max(80, Math.min(width - pad * 2, availH - 80))

        Rectangle {
            anchors.fill: parent
            radius: root.onDesktop ? 12 : 0
            color: "#1e1e22"
            opacity: Plasmoid.configuration.backgroundOpacity
        }

        // ── Header (nur full) ──
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
            anchors.top:       fullView.minimal ? parent.top : header.bottom
            anchors.topMargin: fullView.minimal ? (parent.height - fullView.ringDiam) / 2 : fullView.pad / 2
            width:  fullView.ringDiam
            height: fullView.ringDiam

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2, cy = height / 2
                var lw = Math.max(4, width * 0.055)
                ring(ctx, cx, cy, width * 0.43, lw, root.weeklyPct,  root.theme.w,  root.theme.wT)
                ring(ctx, cx, cy, width * 0.29, lw, root.sessionPct, root.theme.s,  root.theme.sT)
            }
            function ring(ctx, cx, cy, r, lw, pct, color, track) {
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.strokeStyle = track; ctx.lineWidth = lw; ctx.lineCap = "butt"; ctx.stroke()
                var f = Math.min(Math.max(pct, 0), 100) / 100
                if (f <= 0) return
                ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * f)
                ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.stroke()
            }
            Connections {
                target: root
                function onSessionPctChanged() { ringCanvas.requestPaint() }
                function onWeeklyPctChanged()  { ringCanvas.requestPaint() }
                function onLoadingChanged()    { ringCanvas.requestPaint() }
            }
            onWidthChanged: requestPaint()

            // Text in Ringmitte — sauber für beide Ansichten
            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loading ? "…" : Math.round(root.sessionPct) + "%"
                    color: root.theme.s
                    font.pixelSize: Math.max(11, ringCanvas.width * 0.13)
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !fullView.minimal
                    text: i18n("SESSION")
                    color: root.theme.sLbl
                    font.pixelSize: Math.max(6, ringCanvas.width * 0.046)
                    font.letterSpacing: 1.5
                }
            }
        }

        // Minimal-View: Klick auf Ring öffnet Shortcut-Popup
        MouseArea {
            anchors.fill: ringCanvas
            visible: fullView.minimal
            cursorShape: Qt.PointingHandCursor
            onClicked: minimalPopup.visible = !minimalPopup.visible
        }

        Rectangle {
            id: minimalPopup
            visible: false
            anchors.centerIn: parent
            width: parent.width - fullView.pad * 2
            height: minimalPopupCol.implicitHeight + fullView.pad * 2
            color: "#2a2a30"; radius: 10; z: 10

            MouseArea { anchors.fill: parent }

            Column {
                id: minimalPopupCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: fullView.pad }
                spacing: 6

                Repeater {
                    model: {
                        var items = [
                            { label: i18n("New Chat"), icon: "list-add",                 url: "https://claude.ai/new"            },
                            { label: i18n("Usage"),    icon: "utilities-system-monitor", url: "https://claude.ai/settings/usage" }
                        ]
                        if (Plasmoid.configuration.projectShortcutLabel !== "" && Plasmoid.configuration.projectShortcutUrl !== "")
                            items.push({ label: Plasmoid.configuration.projectShortcutLabel, icon: "folder-open", url: Plasmoid.configuration.projectShortcutUrl })
                        return items
                    }
                    PlasmaComponents.Button {
                        width: parent.width
                        text: modelData.label; icon.name: modelData.icon; font.pixelSize: 10
                        onClicked: { Qt.openUrlExternally(modelData.url); minimalPopup.visible = false }
                    }
                }
                PlasmaComponents.Button {
                    width: parent.width
                    text: i18n("Close"); icon.name: "window-close"; font.pixelSize: 10
                    onClicked: minimalPopup.visible = false
                }
            }
        }

        // ── Legende (full view only) ──
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
                Rectangle { width:8; height:8; radius:4; color:root.theme.s; anchors.verticalCenter: parent.verticalCenter }
                Text { text: i18n("Session"); color:"white"; font.pixelSize:11; width:55 }
                Text { text:Math.round(root.sessionPct)+"%"; color:root.theme.s; font.pixelSize:11; font.bold:true; width:34 }
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
                Rectangle { width:8; height:8; radius:4; color:root.theme.w; anchors.verticalCenter:parent.verticalCenter }
                Text { text: i18n("Week"); color:"white"; font.pixelSize:11; width:55 }
                Text { text:Math.round(root.weeklyPct)+"%"; color:root.theme.w; font.pixelSize:11; font.bold:true; width:34 }
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

        // ── Schnelllinks (full view only) ──
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
                    text: "Claude CLI"; icon.name: "utilities-terminal"; font.pixelSize: 10
                    onClicked: { executable.connectSource(root.terminalCmd()); root.expanded = false }
                    PlasmaComponents.ToolTip { text: i18n("Open Claude Code in terminal") }
                }
                PlasmaComponents.Button {
                    width: (buttons.width - 5) / 2
                    text: "VS Code"; icon.name: "vscode"; font.pixelSize: 10
                    onClicked: { executable.connectSource("code --reuse-window"); root.expanded = false }
                    PlasmaComponents.ToolTip { text: i18n("Open last VS Code window") }
                }
            }

            Row {
                width: parent.width
                visible: fullView.hasProjectShortcut
                PlasmaComponents.Button {
                    width: parent.width
                    text: Plasmoid.configuration.projectShortcutLabel; icon.name: "folder-open"; font.pixelSize: 10
                    onClicked: { Qt.openUrlExternally(Plasmoid.configuration.projectShortcutUrl); root.expanded = false }
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
                checkNotifications()
            } catch(e) {
                root.errorMsg = "Parse-Fehler: " + e
            }
        }
    }

    function sendNotif(title, body) {
        executable.connectSource("notify-send -i dialog-warning -t 10000 '" + title + "' '" + body + "'")
    }

    function checkNotifications() {
        var s = root.sessionPct, w = root.weeklyPct
        var si = root.sessionResetsIn, wi = root.weeklyResetsIn

        // Session 80%
        if (Plasmoid.configuration.notifySession80) {
            if (s >= 80 && !root._ns80) {
                root._ns80 = true
                sendNotif("Claude — Session " + Math.round(s) + "%", "Resets in " + si)
            } else if (s < 80) { root._ns80 = false }
        }
        // Session 95%
        if (Plasmoid.configuration.notifySession95) {
            if (s >= 95 && !root._ns95) {
                root._ns95 = true
                sendNotif("Claude — Session " + Math.round(s) + "%", "Resets in " + si)
            } else if (s < 95) { root._ns95 = false }
        }
        // Weekly 80%
        if (Plasmoid.configuration.notifyWeekly80) {
            if (w >= 80 && !root._nw80) {
                root._nw80 = true
                sendNotif("Claude — Weekly " + Math.round(w) + "%", "Resets in " + wi)
            } else if (w < 80) { root._nw80 = false }
        }
        // Weekly 95%
        if (Plasmoid.configuration.notifyWeekly95) {
            if (w >= 95 && !root._nw95) {
                root._nw95 = true
                sendNotif("Claude — Weekly " + Math.round(w) + "%", "Resets in " + wi)
            } else if (w < 95) { root._nw95 = false }
        }
    }

    function fetchData() {
        root.loading = true
        root.errorMsg = ""
        executable.connectSource("python3 \"$HOME/.config/claude-widget/claude_usage.py\"")
    }

    Timer {
        interval: Math.max(5, Plasmoid.configuration.refreshIntervalSeconds) * 1000
        running: Plasmoid.configuration.timerEnabled
        repeat: true
        onTriggered: fetchData()
    }
}
