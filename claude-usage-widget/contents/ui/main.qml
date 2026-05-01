import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Claude.ai mode properties ─────────────────────────────────────────────
    property real sessionPct: 0
    property real weeklyPct: 0
    property string sessionResetsIn: "?"
    property string weeklyResetsIn: "?"
    property string sessionResetsAt: ""
    property string weeklyResetsAt: ""

    // ── API mode properties ───────────────────────────────────────────────────
    readonly property bool apiMode:   Plasmoid.configuration.widgetMode === "api"
    readonly property bool oauthMode: Plasmoid.configuration.widgetMode === "oauth"
    property string planTier: ""
    property string apiTokensDisplay:  "—"
    property string apiCostDisplay:    "—"
    property string apiBudgetDisplay:  "—"
    property real   apiBudgetPct:      0
    property bool   apiHasBudget:      false
    property string apiWindowLabel:    "Monthly"
    // Extended API fields
    property string apiInputDisplay:   "—"
    property string apiOutputDisplay:  "—"
    property string apiCacheDisplay:   "—"
    property string apiSavedDisplay:     ""
    property string apiRemainingDisplay: ""
    property string apiDailyDisplay:   "—"
    property string apiProjectedDisplay: "—"
    property string apiStatusMessage: ""
    property int    apiCacheEfficiency: 0
    property var    apiByModel:        []

    // ── Shared ────────────────────────────────────────────────────────────────
    property string errorMsg: ""
    property bool loading: true
    property bool isAuthError: false
    readonly property int apiMinRefreshSeconds: 120
    readonly property bool apiHasRenderableData: apiTokensDisplay !== "—" || apiCostDisplay !== "—"
    property bool _applyingSharedSettings: false
    property bool _sharedSettingsLoaded: false
    property string _lastSharedSettingsJson: ""
    property string _lastSharedRevision: ""
    property string _lastSyncMtime: ""
    property string _pendingApiCacheKey: ""
    property bool _joiningSharedSettings: false
    readonly property string apiDebugSummary:
        "DBG cap=" + (apiHasBudget ? "yes" : "no") +
        " pct=" + Math.round(apiBudgetPct) +
        " rem=" + (apiRemainingDisplay || "—") +
        " mode=" + (Plasmoid.configuration.apiBudgetMode || "selected")

    // Notification flags — reset on first load to avoid re-firing on plasmashell restart
    property bool _firstLoad: true
    property bool _ns25: false
    property bool _ns50: false
    property bool _ns80: false
    property bool _ns95: false
    property bool _nw25: false
    property bool _nw50: false
    property bool _nw80: false
    property bool _nw95: false

    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property color plasmaBackgroundColor: Kirigami.Theme.backgroundColor
    readonly property real plasmaBackgroundLuma:
        0.2126 * plasmaBackgroundColor.r +
        0.7152 * plasmaBackgroundColor.g +
        0.0722 * plasmaBackgroundColor.b
    readonly property bool plasmaDarkMode: plasmaBackgroundLuma < 0.5
    readonly property string activeThemeKey: {
        if (Plasmoid.configuration.followPlasmaTheme)
            return plasmaDarkMode
                ? (Plasmoid.configuration.darkModeTheme || "violet")
                : (Plasmoid.configuration.lightModeTheme || "amber")
        return Plasmoid.configuration.colorTheme || "amber"
    }

    // ── Color themes ──────────────────────────────────────────────────────────
    function makeThemeColors(s, w) {
        var sc = Qt.color(s), wc = Qt.color(w)
        return {
            s: s, w: w,
            sT:   Qt.rgba(sc.r, sc.g, sc.b, 0.18),
            wT:   Qt.rgba(wc.r, wc.g, wc.b, 0.18),
            sDim: Qt.rgba(sc.r, sc.g, sc.b, 0.6),
            wDim: Qt.rgba(wc.r, wc.g, wc.b, 0.6),
            sLbl: Qt.rgba(sc.r, sc.g, sc.b, 0.5)
        }
    }

    readonly property var theme: {
        var key = activeThemeKey
        if (key === "custom")
            return makeThemeColors(
                Plasmoid.configuration.customSessionColor || "#FF7300",
                Plasmoid.configuration.customWeeklyColor  || "#FFB347"
            )
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
            },
            "emerald": {
                s: "#10B981",              w: "#6EE7B7",
                sT: "rgba(16,185,129,0.18)",  wT: "rgba(110,231,183,0.18)",
                sDim: "rgba(16,185,129,0.6)", wDim: "rgba(110,231,183,0.6)",
                sLbl: "rgba(16,185,129,0.5)"
            },
            "rose": {
                s: "#F43F5E",              w: "#FDA4AF",
                sT: "rgba(244,63,94,0.18)",   wT: "rgba(253,164,175,0.18)",
                sDim: "rgba(244,63,94,0.6)",  wDim: "rgba(253,164,175,0.6)",
                sLbl: "rgba(244,63,94,0.5)"
            }
        }
        return map[key] || map["amber"]
    }
    // Theme repaints are triggered from within each canvas via their Connections blocks

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    toolTipMainText: {
        if (root.loading) return i18n("Loading…")
        if (root.errorMsg) return root.apiMode ? i18n("Claude API — Error") : i18n("Claude — Error")
        if (root.apiMode) {
            var line1 = root.apiTokensDisplay + " tokens" + (Plasmoid.configuration.apiShowCost ? "   ·   " + root.apiCostDisplay : "")
            var line2 = root.apiStatusMessage !== ""
                ? root.apiStatusMessage
                : root.apiWindowLabel + " · " + (root.apiHasBudget ? Math.round(root.apiBudgetPct) + "% of cap" : i18n("No cap countdown"))
            return line1 + "\n" + line2
        }
        return "Session " + Math.round(root.sessionPct) + "%   ·   Week " + Math.round(root.weeklyPct) + "%" +
               "\n" + i18n("Session resets in %1", root.sessionResetsIn) +
               "\n" + i18n("Weekly resets in %1", root.weeklyResetsIn)
    }

    preferredRepresentation: {
        if (onDesktop) return fullRepresentation
        if ((Plasmoid.configuration.sidebarView || "compact") === "full")
            return fullRepresentation
        return compactRepresentation
    }

    Component.onCompleted: initializeWidget()
    onExpandedChanged: { if (expanded) fetchData() }

    function terminalCmd() {
        var term = Plasmoid.configuration.terminalApp.trim() || "konsole"
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

    function currentModeKey() {
        return root.apiMode ? "api" : "claudeai"
    }

    function syncScriptPath() {
        return Qt.resolvedUrl("../code/widget_sync.py").toString().replace("file://", "")
    }

    function apiCacheScriptPath() {
        return Qt.resolvedUrl("../code/api_cache.py").toString().replace("file://", "")
    }

    function currentApiCacheArgs() {
        return {
            window: Plasmoid.configuration.apiTimeWindow || "monthly",
            currency: Plasmoid.configuration.apiCurrency || "EUR",
            cap: String(Plasmoid.configuration.apiBudgetCap || 0),
            capMode: Plasmoid.configuration.apiBudgetMode || "selected"
        }
    }

    function applyApiPayload(j) {
        root.apiStatusMessage = j.message || ""
        root.apiTokensDisplay = j.tokens.display
        root.apiBudgetPct = j.budget.pct
        root.apiHasBudget = j.budget.has_cap
        root.apiCostDisplay = j.cost.display
        root.apiBudgetDisplay = j.cost.budget_display
        root.apiWindowLabel = j.window.charAt(0).toUpperCase() + j.window.slice(1)
        root.apiInputDisplay = (j.tokens && j.tokens.input_display) || "—"
        root.apiOutputDisplay = (j.tokens && j.tokens.output_display) || "—"
        root.apiCacheDisplay = (j.tokens && j.tokens.cache_read_display) || "—"
        root.apiSavedDisplay = (j.cost && j.cost.saved_display) || ""
        root.apiRemainingDisplay = (j.cost && j.cost.remaining_display) || ""
        root.apiDailyDisplay = (j.cost && j.cost.daily_avg_display) || "—"
        root.apiProjectedDisplay = (j.cost && j.cost.projected_display) || "—"
        root.apiCacheEfficiency = j.cache_efficiency || 0
        root.apiByModel = j.by_model || []
    }

    function primeApiCache() {
        if (!root.apiMode)
            return
        var args = currentApiCacheArgs()
        root._pendingApiCacheKey = args.window + "|" + args.currency + "|" + args.cap + "|" + args.capMode
        apiCacheExec.connectSource(
            "python3 \"" + apiCacheScriptPath() + "\" get " +
            args.window + " " + args.currency + " " + args.cap + " " + args.capMode
        )
    }

    function collectSharedSettings(mode) {
        var base = {
            "colorTheme": Plasmoid.configuration.colorTheme || "amber",
            "followPlasmaTheme": Plasmoid.configuration.followPlasmaTheme,
            "lightModeTheme": Plasmoid.configuration.lightModeTheme || "amber",
            "darkModeTheme": Plasmoid.configuration.darkModeTheme || "violet",
            "customSessionColor": Plasmoid.configuration.customSessionColor || "#FF7300",
            "customWeeklyColor": Plasmoid.configuration.customWeeklyColor || "#FFB347",
            "widgetOpacity": Plasmoid.configuration.widgetOpacity,
            "backgroundOpacity": Plasmoid.configuration.backgroundOpacity,
            "timerEnabled": Plasmoid.configuration.timerEnabled,
            "refreshIntervalSeconds": Plasmoid.configuration.refreshIntervalSeconds
        }
        if (mode === "api") {
            base.apiTimeWindow = Plasmoid.configuration.apiTimeWindow || "monthly"
            base.apiShowCost = Plasmoid.configuration.apiShowCost
            base.apiCurrency = Plasmoid.configuration.apiCurrency || "EUR"
            base.apiBudgetCap = Plasmoid.configuration.apiBudgetCap || 0
            base.apiBudgetMode = Plasmoid.configuration.apiBudgetMode || "selected"
            base.apiRingDisplay = Plasmoid.configuration.apiRingDisplay || "remaining"
            return base
        }
        base.terminalApp = Plasmoid.configuration.terminalApp || "konsole"
        base.projectShortcutLabel = Plasmoid.configuration.projectShortcutLabel || ""
        base.projectShortcutUrl = Plasmoid.configuration.projectShortcutUrl || ""
        base.minimalView = Plasmoid.configuration.minimalView
        base.sidebarView = Plasmoid.configuration.sidebarView || "compact"
        base.scriptPath = Plasmoid.configuration.scriptPath || ""
        base.desktopShortcuts = Plasmoid.configuration.desktopShortcuts
        base.notifySession25 = Plasmoid.configuration.notifySession25
        base.notifySession50 = Plasmoid.configuration.notifySession50
        base.notifySession80 = Plasmoid.configuration.notifySession80
        base.notifySession95 = Plasmoid.configuration.notifySession95
        base.notifyWeekly25 = Plasmoid.configuration.notifyWeekly25
        base.notifyWeekly50 = Plasmoid.configuration.notifyWeekly50
        base.notifyWeekly80 = Plasmoid.configuration.notifyWeekly80
        base.notifyWeekly95 = Plasmoid.configuration.notifyWeekly95
        return base
    }

    function applySharedSettings(mode, settings) {
        if (!settings)
            return
        root._applyingSharedSettings = true
        Plasmoid.configuration.colorTheme = settings.colorTheme || Plasmoid.configuration.colorTheme
        if (settings.followPlasmaTheme !== undefined)
            Plasmoid.configuration.followPlasmaTheme = settings.followPlasmaTheme
        Plasmoid.configuration.lightModeTheme = settings.lightModeTheme || Plasmoid.configuration.lightModeTheme
        Plasmoid.configuration.darkModeTheme = settings.darkModeTheme || Plasmoid.configuration.darkModeTheme
        Plasmoid.configuration.customSessionColor = settings.customSessionColor || Plasmoid.configuration.customSessionColor
        Plasmoid.configuration.customWeeklyColor = settings.customWeeklyColor || Plasmoid.configuration.customWeeklyColor
        if (settings.widgetOpacity !== undefined)
            Plasmoid.configuration.widgetOpacity = settings.widgetOpacity
        if (settings.backgroundOpacity !== undefined)
            Plasmoid.configuration.backgroundOpacity = settings.backgroundOpacity
        if (settings.timerEnabled !== undefined)
            Plasmoid.configuration.timerEnabled = settings.timerEnabled
        if (settings.refreshIntervalSeconds !== undefined)
            Plasmoid.configuration.refreshIntervalSeconds = settings.refreshIntervalSeconds
        if (mode === "api") {
            Plasmoid.configuration.apiTimeWindow = settings.apiTimeWindow || Plasmoid.configuration.apiTimeWindow
            if (settings.apiShowCost !== undefined)
                Plasmoid.configuration.apiShowCost = settings.apiShowCost
            Plasmoid.configuration.apiCurrency = settings.apiCurrency || Plasmoid.configuration.apiCurrency
            if (settings.apiBudgetCap !== undefined)
                Plasmoid.configuration.apiBudgetCap = settings.apiBudgetCap
            Plasmoid.configuration.apiBudgetMode = settings.apiBudgetMode || Plasmoid.configuration.apiBudgetMode
            Plasmoid.configuration.apiRingDisplay = settings.apiRingDisplay || Plasmoid.configuration.apiRingDisplay
        } else {
            Plasmoid.configuration.terminalApp = settings.terminalApp || Plasmoid.configuration.terminalApp
            Plasmoid.configuration.projectShortcutLabel = settings.projectShortcutLabel || ""
            Plasmoid.configuration.projectShortcutUrl = settings.projectShortcutUrl || ""
            if (settings.minimalView !== undefined)
                Plasmoid.configuration.minimalView = settings.minimalView
            Plasmoid.configuration.sidebarView = settings.sidebarView || Plasmoid.configuration.sidebarView
            Plasmoid.configuration.scriptPath = settings.scriptPath || ""
            if (settings.desktopShortcuts !== undefined)
                Plasmoid.configuration.desktopShortcuts = settings.desktopShortcuts
            if (settings.notifySession25 !== undefined) Plasmoid.configuration.notifySession25 = settings.notifySession25
            if (settings.notifySession50 !== undefined) Plasmoid.configuration.notifySession50 = settings.notifySession50
            if (settings.notifySession80 !== undefined) Plasmoid.configuration.notifySession80 = settings.notifySession80
            if (settings.notifySession95 !== undefined) Plasmoid.configuration.notifySession95 = settings.notifySession95
            if (settings.notifyWeekly25 !== undefined) Plasmoid.configuration.notifyWeekly25 = settings.notifyWeekly25
            if (settings.notifyWeekly50 !== undefined) Plasmoid.configuration.notifyWeekly50 = settings.notifyWeekly50
            if (settings.notifyWeekly80 !== undefined) Plasmoid.configuration.notifyWeekly80 = settings.notifyWeekly80
            if (settings.notifyWeekly95 !== undefined) Plasmoid.configuration.notifyWeekly95 = settings.notifyWeekly95
        }
        root._applyingSharedSettings = false
        root._lastSharedSettingsJson = JSON.stringify(collectSharedSettings(mode))
    }

    function saveSharedSettings() {
        if (!Plasmoid.configuration.syncSettingsByMode || root._applyingSharedSettings || root._joiningSharedSettings)
            return
        var mode = currentModeKey()
        var payload = JSON.stringify(collectSharedSettings(mode))
        root._lastSharedSettingsJson = payload
        syncExec.connectSource("python3 \"" + syncScriptPath() + "\" set " + mode + " '" + escapeShellArg(payload) + "'")
    }

    function loadSharedSettings() {
        if (!Plasmoid.configuration.syncSettingsByMode) {
            root._joiningSharedSettings = false
            root._sharedSettingsLoaded = true
            primeApiCache()
            fetchData()
            return
        }
        root._joiningSharedSettings = true
        syncExec.connectSource("python3 \"" + syncScriptPath() + "\" get " + currentModeKey())
    }

    function initializeWidget() {
        loadSharedSettings()
    }

    // ── Compact (Panel + Sidebar) ─────────────────────────────────────────────
    compactRepresentation: Item {
        id: compact
        opacity: Plasmoid.configuration.widgetOpacity

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        // h = short side of the panel (height when horizontal, width when vertical)
        readonly property real h:        vertical ? parent.width : parent.height
        readonly property real iconSize: Math.round(h * 0.84)
        readonly property real textW:    Math.round(h * 1.6)
        readonly property real totalW:   iconSize + textW + Math.round(h * 0.25)

        Layout.minimumWidth:   vertical ? parent.width : totalW
        Layout.preferredWidth: vertical ? parent.width : totalW
        Layout.minimumHeight:  vertical
            ? iconSize + Math.round(h * 0.08)
              + (sidebarButtons.visible ? sidebarButtons.implicitHeight + 8 : 0)
            : parent.height
        Layout.fillHeight:     !vertical
        Layout.fillWidth:      vertical

        MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }

        // ── Ring canvas ───────────────────────────────────────────────────────
        Canvas {
            id: compactCanvas
            width:  compact.iconSize
            height: compact.iconSize

            // Sidebar: centered at top; Horizontal: left-aligned, vertically centered
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
                if (root.apiMode) {
                    if (root.apiHasBudget) {
                        arc(ctx, cx, cy, width * 0.38, lw, 1.0, root.theme.sT)
                        arc(ctx, cx, cy, width * 0.38, lw, root.apiBudgetPct / 100, root.theme.s)
                    } else {
                        arc(ctx, cx, cy, width * 0.38, lw, 1.0, root.theme.s)
                    }
                } else {
                    arc(ctx, cx, cy, width * 0.44, lw, 1.0,                   root.theme.wT)
                    arc(ctx, cx, cy, width * 0.44, lw, root.weeklyPct  / 100, root.theme.w)
                    arc(ctx, cx, cy, width * 0.33, lw, 1.0,                   root.theme.sT)
                    arc(ctx, cx, cy, width * 0.33, lw, root.sessionPct / 100, root.theme.s)
                }
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
                function onThemeChanged()        { compactCanvas.requestPaint() }
                function onSessionPctChanged()   { compactCanvas.requestPaint() }
                function onWeeklyPctChanged()    { compactCanvas.requestPaint() }
                function onApiBudgetPctChanged() { compactCanvas.requestPaint() }
                function onLoadingChanged()      { compactCanvas.requestPaint() }
            }
            onWidthChanged: requestPaint()

            // ── Sidebar: claudeai mode text ───────────────────────────────────
            Column {
                visible: compact.vertical && !root.apiMode
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

            // ── Sidebar: API mode text ────────────────────────────────────────
            Column {
                visible: compact.vertical && root.apiMode
                anchors.centerIn: parent
                spacing: 0

                readonly property real bigPx:   Math.max(8, compactCanvas.width * 0.11)
                readonly property real smallPx: Math.max(6, compactCanvas.width * 0.08)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.loading && !root.apiHasRenderableData) ? "…" : root.errorMsg ? "!" : root.apiTokensDisplay
                    color: root.errorMsg ? "#ff5555" : root.theme.s
                    font.pixelSize: parent.bigPx
                    font.bold: true
                    lineHeightMode: Text.FixedHeight
                    lineHeight: parent.bigPx * 1.15
                }
                Text {
                    visible: Plasmoid.configuration.apiShowCost && (!root.loading || root.apiHasRenderableData) && !root.errorMsg
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.apiCostDisplay
                    color: root.theme.sDim
                    font.pixelSize: parent.smallPx
                    font.weight: Font.Medium
                    lineHeightMode: Text.FixedHeight
                    lineHeight: parent.smallPx * 1.15
                }
                Text {
                    visible: !root.errorMsg
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.apiDebugSummary
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: Math.max(5, compactCanvas.width * 0.055)
                    lineHeightMode: Text.FixedHeight
                    lineHeight: font.pixelSize * 1.1
                    width: compactCanvas.width * 1.8
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        // ── Horizontal panel: claudeai mode text ──────────────────────────────
        Column {
            visible: !compact.vertical && !root.apiMode
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

        // ── Horizontal panel: API mode text ───────────────────────────────────
        Column {
            visible: !compact.vertical && root.apiMode
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           compactCanvas.right
            anchors.leftMargin:     Math.round(compact.h * 0.15)
            spacing: 0

            Text {
                width: compact.textW
                text: (root.loading && !root.apiHasRenderableData) ? "…" : root.errorMsg ? "!" : root.apiTokensDisplay
                color: root.errorMsg ? "#ff5555" : root.theme.s
                font.pixelSize: Math.round(compact.h * 0.32)
                font.bold: true
            }
            Text {
                visible: Plasmoid.configuration.apiShowCost
                width: compact.textW
                text: (root.loading && !root.apiHasRenderableData) || root.errorMsg ? "" : root.apiCostDisplay
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Math.round(compact.h * 0.22)
            }
            Text {
                visible: !root.errorMsg
                width: Math.round(compact.h * 3.6)
                text: root.apiDebugSummary
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: Math.round(compact.h * 0.14)
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }

        // ── Sidebar shortcuts — desktop-style labeled buttons ─────────────────
        Column {
            id: sidebarButtons
            visible: compact.vertical && !root.apiMode
                     && (Plasmoid.configuration.sidebarView || "compact") === "compact"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:              compactCanvas.bottom
            anchors.topMargin:        8
            width:                    parent.width - 16
            spacing:                  4

            Row {
                width: parent.width; spacing: 4
                Repeater {
                    model: [
                        { label: i18n("New Chat"), icon: "list-add",                 url: "https://claude.ai/new"            },
                        { label: i18n("Projects"), icon: "folder",                   url: "https://claude.ai/projects"       },
                        { label: i18n("Usage"),    icon: "utilities-system-monitor", url: "https://claude.ai/settings/usage" }
                    ]
                    PlasmaComponents.Button {
                        width: (sidebarButtons.width - 8) / 3
                        text: modelData.label; icon.name: modelData.icon; font.pixelSize: 10
                        onClicked: Qt.openUrlExternally(modelData.url)
                    }
                }
            }

            Row {
                width: parent.width; spacing: 4
                PlasmaComponents.Button {
                    width: (sidebarButtons.width - 4) / 2
                    text: "Claude CLI"; icon.name: "utilities-terminal"; font.pixelSize: 10
                    onClicked: executable.connectSource(root.terminalCmd())
                    PlasmaComponents.ToolTip { text: i18n("Open Claude Code in terminal") }
                }
                PlasmaComponents.Button {
                    width: (sidebarButtons.width - 4) / 2
                    text: "VS Code"; icon.name: "vscode"; font.pixelSize: 10
                    onClicked: executable.connectSource("code --reuse-window")
                    PlasmaComponents.ToolTip { text: i18n("Open last VS Code window") }
                }
            }

            Row {
                width: parent.width
                visible: Plasmoid.configuration.projectShortcutLabel !== ""
                         && Plasmoid.configuration.projectShortcutUrl !== ""
                PlasmaComponents.Button {
                    width: parent.width
                    text: Plasmoid.configuration.projectShortcutLabel
                    icon.name: "folder-open"; font.pixelSize: 10
                    onClicked: Qt.openUrlExternally(Plasmoid.configuration.projectShortcutUrl)
                    PlasmaComponents.ToolTip { text: Plasmoid.configuration.projectShortcutUrl }
                }
            }
        }
    }

    // ── Full (Desktop & Popup) ────────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullView
        opacity: Plasmoid.configuration.widgetOpacity

        // minimalView is claude.ai-only; force off in API mode
        readonly property bool minimal: Plasmoid.configuration.minimalView && !root.apiMode
        readonly property real pad:     16
        readonly property real headerH: 36
        readonly property bool hasProjectShortcut:
            !root.apiMode &&
            Plasmoid.configuration.projectShortcutLabel !== "" &&
            Plasmoid.configuration.projectShortcutUrl   !== ""
        readonly property real buttonsH: root.apiMode ? 44 : (hasProjectShortcut ? 100 : 70)

        Layout.minimumWidth:   minimal ? 120 : 220
        Layout.minimumHeight:  minimal ? 120 : (root.apiMode ? 500 : 300)
        Layout.preferredWidth: minimal ? 180 : (onDesktop ? 340 : 280)
        Layout.fillWidth:      true
        Layout.fillHeight:     true

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

        // ── Header ──
        Item {
            id: header
            visible: !fullView.minimal
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: fullView.pad }
            height: fullView.headerH

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.apiMode ? "Claude API" : "Claude"
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

        // ── Error display ──
        Column {
            visible: root.errorMsg !== ""
            anchors { top: header.bottom; left: parent.left; right: parent.right; margins: fullView.pad }
            spacing: 8

            Text {
                width: parent.width
                text: root.isAuthError
                    ? (root.apiMode
                        ? i18n("Organization Admin API key missing or invalid.")
                        : root.oauthMode
                            ? i18n("Claude Code not logged in.")
                            : i18n("Session key missing or expired."))
                    : root.errorMsg
                color: "#ff5555"; wrapMode: Text.Wrap
                font.pixelSize: Math.max(10, fullView.ringDiam * 0.07)
            }
            Text {
                visible: root.isAuthError
                width: parent.width
                text: root.apiMode
                    ? i18n("Add an Anthropic organization Admin API key in the widget settings. Individual accounts and standard API keys do not expose Usage & Cost Admin API data.")
                    : root.oauthMode
                        ? i18n("Run `claude` in a terminal to log in with Claude Code.")
                        : i18n("Run setup.sh from the widget repository, or paste your sessionKey from claude.ai cookies.")
                color: Qt.rgba(1,1,1,0.5); wrapMode: Text.Wrap
                font.pixelSize: Math.max(9, fullView.ringDiam * 0.06)
            }
            PlasmaComponents.Button {
                visible: root.isAuthError
                text: root.apiMode ? i18n("Open API Console") : i18n("Open Setup Guide")
                icon.name: root.apiMode ? "internet-web-browser" : "help-contents"
                font.pixelSize: 10
                onClicked: Qt.openUrlExternally(root.apiMode
                    ? "https://console.anthropic.com/settings/keys"
                    : root.oauthMode
                        ? "https://claude.ai/login"
                        : "https://github.com/GitGoodFabi/claude-arch-widget#installation")
            }
        }

        // ── Claude.ai Rings ──
        Canvas {
            id: ringCanvas
            visible: root.errorMsg === "" && !root.apiMode
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
                function onThemeChanged()      { ringCanvas.requestPaint() }
                function onSessionPctChanged() { ringCanvas.requestPaint() }
                function onWeeklyPctChanged()  { ringCanvas.requestPaint() }
                function onLoadingChanged()    { ringCanvas.requestPaint() }
            }
            onWidthChanged: requestPaint()

            // Text centered in the ring
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

        // Minimal view: clicking the ring opens the shortcut popup
        MouseArea {
            anchors.fill: ringCanvas
            visible: fullView.minimal && !root.apiMode
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

        // ── API mode: always-visible ring; uses cap progress when configured ──
        Canvas {
            id: apiRingCanvas
            visible: root.errorMsg === "" && root.apiMode
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:       header.bottom
            anchors.topMargin: fullView.pad / 2
            width:  Math.min(fullView.ringDiam, 110)
            height: Math.min(fullView.ringDiam, 110)

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2, cy = height / 2
                var lw = Math.max(4, width * 0.055)
                var r  = width * 0.38
                var f = Math.min(Math.max(root.apiBudgetPct, 0), 100) / 100
                if (!root.apiHasBudget) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.strokeStyle = root.theme.s
                    ctx.lineWidth = lw
                    ctx.lineCap = "butt"
                    ctx.stroke()
                    return
                }
                // Track
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.strokeStyle = root.theme.sT; ctx.lineWidth = lw; ctx.lineCap = "butt"; ctx.stroke()
                // Fill
                if (f > 0) {
                    ctx.beginPath()
                    if (f >= 1.0)
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    else
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * f)
                    ctx.strokeStyle = root.theme.s; ctx.lineWidth = lw
                    ctx.lineCap = f >= 1.0 ? "butt" : "round"; ctx.stroke()
                }
            }
            Connections {
                target: root
                function onThemeChanged()        { apiRingCanvas.requestPaint() }
                function onApiBudgetPctChanged() { apiRingCanvas.requestPaint() }
                function onApiHasBudgetChanged() { apiRingCanvas.requestPaint() }
                function onLoadingChanged()      { apiRingCanvas.requestPaint() }
            }
            onWidthChanged: requestPaint()

            // Inside the ring: cap details when configured, otherwise a neutral API label
            Column {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.apiHasBudget
                        ? ((root.loading && !root.apiHasRenderableData)
                            ? "…"
                            : (Plasmoid.configuration.apiRingDisplay === "remaining"
                                ? root.apiRemainingDisplay
                                : Math.round(root.apiBudgetPct) + "%"))
                        : i18n("API")
                    color: root.theme.s
                    font.pixelSize: root.apiHasBudget
                        ? (Plasmoid.configuration.apiRingDisplay === "remaining"
                            ? Math.max(12, apiRingCanvas.width * 0.11)
                            : Math.max(22, apiRingCanvas.width * 0.22))
                        : Math.max(14, apiRingCanvas.width * 0.16)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: apiRingCanvas.width * 0.72
                }
                Text {
                    visible: root.apiHasBudget && Plasmoid.configuration.apiShowCost
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.apiBudgetDisplay
                    color: root.theme.s
                    font.pixelSize: Math.max(9, apiRingCanvas.width * 0.08)
                    opacity: 1.0
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.apiHasBudget
                        ? (Plasmoid.configuration.apiRingDisplay === "remaining" ? i18n("LEFT") : i18n("CAP"))
                        : root.apiWindowLabel.toUpperCase()
                    color: root.theme.s
                    font.pixelSize: root.apiHasBudget
                        ? Math.max(7, apiRingCanvas.width * 0.065)
                        : Math.max(7, apiRingCanvas.width * 0.08)
                    font.letterSpacing: 1.5
                    opacity: 0.55
                }
            }
        }

        // ── API mode: headline tokens + cost (below ring / below header when no cap) ──
        Column {
            id: apiStats
            visible: root.errorMsg === "" && root.apiMode
            anchors.top:              apiRingCanvas.bottom
            anchors.topMargin:        10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.loading && !root.apiHasRenderableData) ? "…" : root.apiTokensDisplay
                color: root.theme.s
                font.pixelSize: root.apiHasBudget
                    ? Math.max(14, fullView.ringDiam * 0.12)
                    : Math.max(32, fullView.ringDiam * 0.28)
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n("TOKENS")
                color: root.theme.sLbl
                font.pixelSize: Math.max(7, fullView.ringDiam * 0.044)
                font.letterSpacing: 1.5
            }
            Text {
                visible: Plasmoid.configuration.apiShowCost && (!root.loading || root.apiHasRenderableData)
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.apiCostDisplay
                color: "white"
                font.pixelSize: root.apiHasBudget
                    ? Math.max(12, fullView.ringDiam * 0.09)
                    : Math.max(22, fullView.ringDiam * 0.18)
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.apiDebugSummary
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 10
                wrapMode: Text.WrapAnywhere
                horizontalAlignment: Text.AlignHCenter
                width: fullView.width - (fullView.pad * 2)
            }
        }

        // ── API mode: legend/details (scrollable to avoid overlap in smaller popups) ──
        Flickable {
            id: apiLegendScroll
            visible: root.errorMsg === "" && root.apiMode && (!root.loading || root.apiHasRenderableData)
            anchors {
                top: apiStats.bottom
                topMargin: 10
                bottom: apiButtons.top
                bottomMargin: 8
                left: parent.left
                right: parent.right
                leftMargin: fullView.pad
                rightMargin: fullView.pad
            }
            contentWidth: width
            contentHeight: apiLegend.implicitHeight
            clip: true

            Column {
                id: apiLegend
                width: apiLegendScroll.width
                spacing: 4

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }
                Item { width: 1; height: 2 }

                Text {
                    visible: root.apiStatusMessage !== ""
                    width: parent.width
                    text: root.apiStatusMessage
                    color: Qt.rgba(1,1,1,0.55)
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Row {
                    width: parent.width; spacing: 6
                    Rectangle { width:8; height:8; radius:4; color:root.theme.s; anchors.verticalCenter:parent.verticalCenter }
                    Text { text: i18n("Input");  color:"white"; font.pixelSize:11; width:72 }
                    Text { text: root.apiInputDisplay; color:root.theme.s; font.pixelSize:11; font.bold:true }
                }
                Row {
                    width: parent.width; spacing: 6
                    Rectangle { width:8; height:8; radius:4; color:root.theme.w; anchors.verticalCenter:parent.verticalCenter }
                    Text { text: i18n("Output"); color:"white"; font.pixelSize:11; width:72 }
                    Text { text: root.apiOutputDisplay; color:root.theme.w; font.pixelSize:11; font.bold:true }
                }
                Row {
                    width: parent.width; spacing: 6
                    Rectangle { width:8; height:8; radius:4; color:Qt.rgba(1,1,1,0.28); anchors.verticalCenter:parent.verticalCenter }
                    Text { text: i18n("Cache read"); color:"white"; font.pixelSize:11; width:72 }
                    Text { text: root.apiCacheDisplay; color:Qt.rgba(1,1,1,0.55); font.pixelSize:11; font.bold:true }
                    Text { text: root.apiCacheEfficiency + "% hit"; color:Qt.rgba(1,1,1,0.35); font.pixelSize:10; anchors.verticalCenter:parent.verticalCenter }
                }
                Text {
                    visible: root.apiCacheEfficiency > 0 && root.apiSavedDisplay !== ""
                    width: parent.width
                    text: root.apiSavedDisplay + " via prompt caching"
                    color: Qt.rgba(1,1,1,0.28)
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
                Text {
                    visible: root.apiHasBudget && root.apiRemainingDisplay !== ""
                    width: parent.width
                    text: root.apiRemainingDisplay
                    color: Qt.rgba(1,1,1,0.5)
                    font.pixelSize: 10
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }
                Item { width: 1; height: 2 }

                Repeater {
                    model: root.apiByModel
                    Row {
                        width: parent.width; spacing: 6
                        Rectangle { width:8; height:8; radius:4; color:root.theme.s; opacity: index === 0 ? 1.0 : 0.5; anchors.verticalCenter:parent.verticalCenter }
                        Text { text: modelData.display; color:"white"; font.pixelSize:11; width:72; elide:Text.ElideRight }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4; radius: 2; color: root.theme.s; opacity: 0.55
                            width: Math.max(2, (parent.width - 8 - 6 - 72 - 6 - 52 - 6) * modelData.pct / 100)
                        }
                        Text {
                            text: modelData.cost_display
                            color:Qt.rgba(1,1,1,0.45)
                            font.pixelSize:11
                            width:52
                            horizontalAlignment:Text.AlignRight
                            anchors.verticalCenter:parent.verticalCenter
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }
                Item { width: 1; height: 2 }

                Row {
                    visible: Plasmoid.configuration.apiShowCost
                    width: parent.width; spacing: 6
                    Text { text: i18n("Daily avg"); color:"white"; font.pixelSize:11; width:72 }
                    Text { text: root.apiDailyDisplay; color:root.theme.w; font.pixelSize:11; font.bold:true }
                    Text { text: "·"; color:Qt.rgba(1,1,1,0.3); font.pixelSize:11; leftPadding: 4 }
                    Text { text: i18n("Projected"); color:Qt.rgba(1,1,1,0.5); font.pixelSize:11; leftPadding: 4 }
                    Text { text: root.apiProjectedDisplay; color:Qt.rgba(1,1,1,0.7); font.pixelSize:11; font.bold:true }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.apiWindowLabel
                    color: Qt.rgba(1,1,1,0.22)
                    font.pixelSize: 9
                    font.letterSpacing: 0.5
                }
            }
        }

        // ── API mode: quick links (mirrors claude.ai buttons — anchored to bottom) ──
        Column {
            id: apiButtons
            visible: !fullView.minimal && root.apiMode
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                      margins: fullView.pad; bottomMargin: fullView.pad }
            spacing: 5

            Row {
                width: parent.width; spacing: 5
                PlasmaComponents.Button {
                    width: (apiButtons.width - 5) / 2
                    text: i18n("API Console"); icon.name: "internet-web-browser"; font.pixelSize: 10
                    onClicked: { Qt.openUrlExternally("https://console.anthropic.com"); root.expanded = false }
                    PlasmaComponents.ToolTip { text: "console.anthropic.com" }
                }
                PlasmaComponents.Button {
                    width: (apiButtons.width - 5) / 2
                    text: i18n("Billing"); icon.name: "utilities-system-monitor"; font.pixelSize: 10
                    onClicked: { Qt.openUrlExternally("https://console.anthropic.com/settings/billing"); root.expanded = false }
                    PlasmaComponents.ToolTip { text: i18n("Open billing & usage page") }
                }
            }
        }

        // ── Legend (claudeai mode only) ──
        Column {
            id: legend
            visible: root.errorMsg === "" && !fullView.minimal && !root.apiMode
            anchors { bottom: buttons.top; left: parent.left; right: parent.right
                      margins: fullView.pad; bottomMargin: 8 }
            spacing: 4

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }
            Item { width: 1; height: 2 }

            Row {
                width: parent.width; spacing: 6
                Rectangle { width:8; height:8; radius:4; color:root.theme.s; anchors.verticalCenter: parent.verticalCenter }
                Text { text: i18n("Session (5h)"); color:"white"; font.pixelSize:11; width:68 }
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
                Text { text: i18n("Week"); color:"white"; font.pixelSize:11; width:68 }
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

        // ── Quick links (claudeai mode only) ──
        Column {
            id: buttons
            visible: !fullView.minimal && Plasmoid.configuration.desktopShortcuts && !root.apiMode
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

    // ── Data fetching ─────────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            // Always clear loading state first, even on failure
            root.loading = false
            if (!out.startsWith("{")) {
                root.errorMsg = (data["stderr"] || i18n("Script failed")).trim()
                return
            }
            try {
                var j = JSON.parse(out)
                if (j.error) {
                    root.errorMsg = j.error
                    root.isAuthError = j.error.toLowerCase().indexOf("session key") !== -1
                        || j.error.toLowerCase().indexOf("api key") !== -1
                        || j.error.toLowerCase().indexOf("organization") !== -1
                        || j.error.toLowerCase().indexOf("credentials.json") !== -1
                        || j.error.toLowerCase().indexOf("token") !== -1
                        || j.error.indexOf("401") !== -1
                        || j.error.indexOf("403") !== -1
                    return
                }
                if (data["exit code"] !== 0) {
                    root.errorMsg = (data["stderr"] || i18n("Script failed")).trim()
                    return
                }
                root.errorMsg = ""
                if (j.mode === "api") {
                    applyApiPayload(j)
                    var args = currentApiCacheArgs()
                    apiCacheExec.connectSource(
                        "python3 \"" + apiCacheScriptPath() + "\" set " +
                        args.window + " " + args.currency + " " + args.cap + " " + args.capMode +
                        " '" + escapeShellArg(JSON.stringify(j)) + "'"
                    )
                } else {
                    root.apiStatusMessage = ""
                    root.sessionPct      = j.session.utilization
                    root.sessionResetsIn = j.session.resets_in
                    root.sessionResetsAt = j.session.resets_at
                    root.weeklyPct       = j.weekly.utilization
                    root.weeklyResetsIn  = j.weekly.resets_in
                    root.weeklyResetsAt  = j.weekly.resets_at
                    if (j.plan !== undefined) root.planTier = j.plan
                    checkNotifications()
                }
            } catch(e) {
                root.errorMsg = "Parse error: " + String(e)
            }
        }
    }

    Plasma5Support.DataSource {
        id: syncExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            if (!out.startsWith("{")) {
                root._joiningSharedSettings = false
                if (!root._sharedSettingsLoaded) {
                    root._sharedSettingsLoaded = true
                    fetchData()
                }
                return
            }
            try {
                var j = JSON.parse(out)
                if (j.ok && (j.action === "get" || j.action === "set")) {
                    var sharedJson = JSON.stringify(j.settings || {})
                    root._lastSharedRevision = j.revision || ""
                    if (j.found && sharedJson !== root._lastSharedSettingsJson)
                        applySharedSettings(j.mode, j.settings || {})
                    else if (!j.found) {
                        root._joiningSharedSettings = false
                        saveSharedSettings()
                    }
                    root._joiningSharedSettings = false
                    if (!root._sharedSettingsLoaded) {
                        root._sharedSettingsLoaded = true
                        primeApiCache()
                        fetchData()
                    }
                }
            } catch (e) {
                root._joiningSharedSettings = false
            }
        }
    }

    Plasma5Support.DataSource {
        id: syncWatchExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            if (!Plasmoid.configuration.syncSettingsByMode)
                return
            var mtime = (data["stdout"] || "0").trim()
            if (mtime !== "0" && mtime !== root._lastSyncMtime) {
                root._lastSyncMtime = mtime
                syncExec.connectSource("python3 \"" + syncScriptPath() + "\" get " + currentModeKey())
            }
        }
    }

    Plasma5Support.DataSource {
        id: apiCacheExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            if (!out.startsWith("{"))
                return
            try {
                var j = JSON.parse(out)
                if (j.ok && j.action === "get" && j.found && j.payload && j.payload.mode === "api")
                    applyApiPayload(j.payload)
            } catch (e) {
            }
        }
    }

    // Escape single quotes for use inside single-quoted shell arguments
    function escapeShellArg(s) {
        return s.replace(/'/g, "'\\''")
    }

    function sendNotif(title, body) {
        executable.connectSource(
            "notify-send -i dialog-warning -t 10000 '" +
            escapeShellArg(title) + "' '" + escapeShellArg(body) + "'"
        )
    }

    function checkNotifications() {
        var s = root.sessionPct, w = root.weeklyPct
        var si = root.sessionResetsIn, wi = root.weeklyResetsIn

        // On first load, silently mark already-crossed thresholds as seen.
        // This prevents a flood of notifications every time plasmashell restarts.
        if (root._firstLoad) {
            root._ns25 = s >= 25; root._ns50 = s >= 50
            root._ns80 = s >= 80; root._ns95 = s >= 95
            root._nw25 = w >= 25; root._nw50 = w >= 50
            root._nw80 = w >= 80; root._nw95 = w >= 95
            root._firstLoad = false
            return
        }

        if (Plasmoid.configuration.notifySession25) {
            if (s >= 25 && !root._ns25) { root._ns25 = true; sendNotif("Claude — Session " + Math.round(s) + "%", i18n("Resets in %1", si)) }
            else if (s < 25) { root._ns25 = false }
        }
        if (Plasmoid.configuration.notifySession50) {
            if (s >= 50 && !root._ns50) { root._ns50 = true; sendNotif("Claude — Session " + Math.round(s) + "%", i18n("Resets in %1", si)) }
            else if (s < 50) { root._ns50 = false }
        }
        if (Plasmoid.configuration.notifySession80) {
            if (s >= 80 && !root._ns80) { root._ns80 = true; sendNotif("Claude — Session " + Math.round(s) + "%", i18n("Resets in %1", si)) }
            else if (s < 80) { root._ns80 = false }
        }
        if (Plasmoid.configuration.notifySession95) {
            if (s >= 95 && !root._ns95) { root._ns95 = true; sendNotif("Claude — Session " + Math.round(s) + "%", i18n("Resets in %1", si)) }
            else if (s < 95) { root._ns95 = false }
        }
        if (Plasmoid.configuration.notifyWeekly25) {
            if (w >= 25 && !root._nw25) { root._nw25 = true; sendNotif("Claude — Weekly " + Math.round(w) + "%", i18n("Resets in %1", wi)) }
            else if (w < 25) { root._nw25 = false }
        }
        if (Plasmoid.configuration.notifyWeekly50) {
            if (w >= 50 && !root._nw50) { root._nw50 = true; sendNotif("Claude — Weekly " + Math.round(w) + "%", i18n("Resets in %1", wi)) }
            else if (w < 50) { root._nw50 = false }
        }
        if (Plasmoid.configuration.notifyWeekly80) {
            if (w >= 80 && !root._nw80) { root._nw80 = true; sendNotif("Claude — Weekly " + Math.round(w) + "%", i18n("Resets in %1", wi)) }
            else if (w < 80) { root._nw80 = false }
        }
        if (Plasmoid.configuration.notifyWeekly95) {
            if (w >= 95 && !root._nw95) { root._nw95 = true; sendNotif("Claude — Weekly " + Math.round(w) + "%", i18n("Resets in %1", wi)) }
            else if (w < 95) { root._nw95 = false }
        }
    }

    function fetchData() {
        root.loading = true
        root.errorMsg = ""
        root.isAuthError = false
        if (root.apiMode) {
            var apiKey = (Plasmoid.configuration.apiKey || "").trim()
            var window   = Plasmoid.configuration.apiTimeWindow || "monthly"
            var currency = Plasmoid.configuration.apiCurrency   || "EUR"
            var cap      = Plasmoid.configuration.apiBudgetCap  || 0
            var capMode  = Plasmoid.configuration.apiBudgetMode || "selected"
            var apiPath  = Qt.resolvedUrl("../code/api_usage.py").toString().replace("file://", "")
            var cmd = ""
            if (apiKey !== "") {
                cmd =
                    "mkdir -p ~/.config/claude-widget && " +
                    "printf '%s' '" + escapeShellArg(apiKey) + "' > ~/.config/claude-widget/api_key.txt && " +
                    "chmod 600 ~/.config/claude-widget/api_key.txt && "
                // Keep the runtime key on disk, but clear the plasmoid config copy.
                Plasmoid.configuration.apiKey = ""
            }
            cmd += "python3 \"" + apiPath + "\" " + window + " " + currency + " " + cap + " " + capMode
            executable.connectSource(cmd)
        } else {
            var path = (Plasmoid.configuration.scriptPath || "").trim()
            if (!path)
                path = Qt.resolvedUrl("../code/claude_usage.py").toString().replace("file://", "")
            var args = root.oauthMode ? " oauth" : ""
            executable.connectSource("python3 \"" + path + "\"" + args)
        }
    }

    Timer {
        id: sharedSettingsSaveTimer
        interval: 250
        repeat: false
        onTriggered: saveSharedSettings()
    }

    Timer {
        id: syncPollTimer
        interval: 5000
        running: Plasmoid.configuration.syncSettingsByMode
        repeat: true
        onTriggered: {
            syncWatchExec.connectSource(
                "stat -c %Y ~/.config/claude-widget/mode_sync.json 2>/dev/null || echo 0"
            )
        }
    }

    Timer {
        interval: Math.max(root.apiMode ? root.apiMinRefreshSeconds : 5,
                           Plasmoid.configuration.refreshIntervalSeconds) * 1000
        running: Plasmoid.configuration.timerEnabled
        repeat: true
        onTriggered: fetchData()
    }

    Connections {
        target: Plasmoid.configuration
        function onWidgetModeChanged() {
            if (root._applyingSharedSettings)
                return
            if (root.apiMode)
                primeApiCache()
            loadSharedSettings()
        }
        function onSyncSettingsByModeChanged() {
            if (root._applyingSharedSettings)
                return
            if (Plasmoid.configuration.syncSettingsByMode)
                loadSharedSettings()
        }
        function onApiTimeWindowChanged() { primeApiCache(); sharedSettingsSaveTimer.restart() }
        function onApiShowCostChanged() { sharedSettingsSaveTimer.restart() }
        function onApiCurrencyChanged() { primeApiCache(); sharedSettingsSaveTimer.restart() }
        function onApiBudgetCapChanged() { primeApiCache(); sharedSettingsSaveTimer.restart() }
        function onApiBudgetModeChanged() { primeApiCache(); sharedSettingsSaveTimer.restart() }
        function onColorThemeChanged() { sharedSettingsSaveTimer.restart() }
        function onFollowPlasmaThemeChanged() { sharedSettingsSaveTimer.restart() }
        function onLightModeThemeChanged() { sharedSettingsSaveTimer.restart() }
        function onDarkModeThemeChanged() { sharedSettingsSaveTimer.restart() }
        function onCustomSessionColorChanged() { sharedSettingsSaveTimer.restart() }
        function onCustomWeeklyColorChanged() { sharedSettingsSaveTimer.restart() }
        function onWidgetOpacityChanged() { sharedSettingsSaveTimer.restart() }
        function onBackgroundOpacityChanged() { sharedSettingsSaveTimer.restart() }
        function onTerminalAppChanged() { sharedSettingsSaveTimer.restart() }
        function onTimerEnabledChanged() { sharedSettingsSaveTimer.restart() }
        function onRefreshIntervalSecondsChanged() { sharedSettingsSaveTimer.restart() }
        function onProjectShortcutLabelChanged() { sharedSettingsSaveTimer.restart() }
        function onProjectShortcutUrlChanged() { sharedSettingsSaveTimer.restart() }
        function onMinimalViewChanged() { sharedSettingsSaveTimer.restart() }
        function onSidebarViewChanged() { sharedSettingsSaveTimer.restart() }
        function onScriptPathChanged() { sharedSettingsSaveTimer.restart() }
        function onDesktopShortcutsChanged() { sharedSettingsSaveTimer.restart() }
        function onNotifySession25Changed() { sharedSettingsSaveTimer.restart() }
        function onNotifySession50Changed() { sharedSettingsSaveTimer.restart() }
        function onNotifySession80Changed() { sharedSettingsSaveTimer.restart() }
        function onNotifySession95Changed() { sharedSettingsSaveTimer.restart() }
        function onNotifyWeekly25Changed() { sharedSettingsSaveTimer.restart() }
        function onNotifyWeekly50Changed() { sharedSettingsSaveTimer.restart() }
        function onNotifyWeekly80Changed() { sharedSettingsSaveTimer.restart() }
        function onNotifyWeekly95Changed() { sharedSettingsSaveTimer.restart() }
    }
}
