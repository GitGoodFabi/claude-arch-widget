import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Item {
    id: configRoot
    // cfg_* properties must live on the root item for the KDE config system
    property string title: i18n("General")

    // Plasma injects cfg_*Default values into the config page root item.
    // Define them explicitly so the config dialog can initialize cleanly.
    property string cfg_widgetModeDefault: "claudeai"
    property bool cfg_syncSettingsByModeDefault: true
    property string cfg_apiKeyDefault: ""
    property string cfg_apiTimeWindowDefault: "monthly"
    property bool cfg_apiShowCostDefault: true
    property string cfg_apiCurrencyDefault: "EUR"
    property double cfg_apiBudgetCapDefault: 0
    property string cfg_apiBudgetModeDefault: "selected"
    property string cfg_apiRingDisplayDefault: "remaining"
    property double cfg_backgroundOpacityDefault: 0.0
    property string cfg_colorThemeDefault: "amber"
    property bool cfg_followPlasmaThemeDefault: false
    property string cfg_lightModeThemeDefault: "amber"
    property string cfg_darkModeThemeDefault: "violet"
    property string cfg_customSessionColorDefault: "#FF7300"
    property string cfg_customWeeklyColorDefault: "#FFB347"
    property bool cfg_desktopShortcutsDefault: true
    property bool cfg_minimalViewDefault: false
    property bool cfg_notifySession25Default: false
    property bool cfg_notifySession50Default: false
    property bool cfg_notifySession80Default: false
    property bool cfg_notifySession95Default: false
    property bool cfg_notifyWeekly25Default: false
    property bool cfg_notifyWeekly50Default: false
    property bool cfg_notifyWeekly80Default: false
    property bool cfg_notifyWeekly95Default: false
    property string cfg_projectShortcutLabelDefault: ""
    property string cfg_projectShortcutUrlDefault: ""
    property int cfg_refreshIntervalSecondsDefault: 300
    property string cfg_scriptPathDefault: ""
    property string cfg_sidebarViewDefault: "compact"
    property string cfg_terminalAppDefault: "konsole"
    property bool cfg_timerEnabledDefault: true
    property double cfg_widgetOpacityDefault: 1.0

    // ── Mode ──────────────────────────────────────────────────────────────────
    property alias cfg_widgetMode:    modeCombo.currentValue
    property alias cfg_syncSettingsByMode: syncSettingsToggle.checked
    property alias  cfg_apiKey:       apiKeyField.text
    property alias cfg_apiTimeWindow: apiWindowCombo.currentValue
    property alias cfg_apiShowCost:   apiShowCostToggle.checked
    property alias cfg_apiCurrency:   apiCurrencyCombo.currentValue
    property alias cfg_apiBudgetCap:  budgetCapValue.value
    property alias cfg_apiBudgetMode: apiBudgetModeCombo.currentValue
    property alias cfg_apiRingDisplay: apiRingDisplayCombo.currentValue

    // ── Appearance & Claude.ai settings ──────────────────────────────────────
    property alias cfg_colorTheme:            themeCombo.currentValue
    property alias cfg_followPlasmaTheme:     followPlasmaThemeToggle.checked
    property alias cfg_lightModeTheme:        lightThemeCombo.currentValue
    property alias cfg_darkModeTheme:         darkThemeCombo.currentValue
    property string cfg_customSessionColor:   "#FF7300"
    property string cfg_customWeeklyColor:    "#FFB347"
    property alias cfg_widgetOpacity:         widgetOpacitySlider.value
    property alias cfg_backgroundOpacity:     opacitySlider.value
    property alias cfg_terminalApp:           terminalField.text
    property alias cfg_timerEnabled:          timerToggle.checked
    property alias cfg_refreshIntervalSeconds: intervalCombo.currentValue
    property alias cfg_projectShortcutLabel:  projectLabelField.text
    property alias cfg_projectShortcutUrl:    projectUrlField.text
    property alias cfg_minimalView:           minimalToggle.checked
    property alias cfg_sidebarView:           sidebarViewCombo.currentValue
    property alias cfg_scriptPath:            scriptPathField.text
    property alias cfg_notifySession25: notifyS25.checked
    property alias cfg_notifySession50: notifyS50.checked
    property alias cfg_notifySession80: notifyS80.checked
    property alias cfg_notifySession95: notifyS95.checked
    property alias cfg_notifyWeekly25:  notifyW25.checked
    property alias cfg_notifyWeekly50:  notifyW50.checked
    property alias cfg_notifyWeekly80:  notifyW80.checked
    property alias cfg_notifyWeekly95:  notifyW95.checked
    property alias cfg_desktopShortcuts: desktopShortcutsToggle.checked

    Kirigami.FormLayout {
        id: configPage
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom }

    readonly property bool isApiMode: modeCombo.currentValue === "api"

    QtObject {
        id: budgetCapValue
        property double value: 0
    }

    // ── Widget mode ───────────────────────────────────────────────────────────
    PlasmaComponents.ComboBox {
        id: modeCombo
        Kirigami.FormData.label: i18n("Widget mode:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: i18n("Claude.ai  (Pro / Max)"), value: "claudeai" },
            { label: i18n("Anthropic API"),           value: "api"      }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_widgetMode) { currentIndex = i; break }
            }
        }
    }

    Row {
        Kirigami.FormData.label: i18n("Shared mode settings:")
        spacing: 6

        PlasmaComponents.CheckBox {
            id: syncSettingsToggle
            text: i18n("Sync with all widgets in this mode")
        }

        PlasmaComponents.Label {
            id: syncInfoLabel
            text: i18n("(i)")
            color: Kirigami.Theme.disabledTextColor
            font.bold: true

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            PlasmaComponents.ToolTip.text: i18n("When enabled, all Claude.ai widgets share one preset and all API widgets share another. Existing widgets only join the shared preset after you enable this option for them.")
            PlasmaComponents.ToolTip.visible: syncInfoLabel.children[0].containsMouse
        }
    }

    // ── API settings (visible in API mode only) ───────────────────────────────
    PlasmaComponents.TextField {
        id: apiKeyField
        visible: configPage.isApiMode
        Kirigami.FormData.label: i18n("Org Admin API key:")
        placeholderText: i18n("Paste new key to replace saved key")
        echoMode: TextInput.Password
        Layout.maximumWidth: 260
        PlasmaComponents.ToolTip.text: i18n("Requires an Anthropic organization Admin API key. A pasted key is written to the local widget config file and does not need to stay in this field.")
        PlasmaComponents.ToolTip.visible: hovered
    }

    PlasmaComponents.ComboBox {
        id: apiWindowCombo
        visible: configPage.isApiMode
        Kirigami.FormData.label: i18n("Time window:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: i18n("Daily"),   value: "daily"   },
            { label: i18n("Weekly"),  value: "weekly"  },
            { label: i18n("Monthly"), value: "monthly" },
            { label: i18n("All time (12 months)"), value: "all" }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_apiTimeWindow) { currentIndex = i; break }
            }
        }
    }

    PlasmaComponents.CheckBox {
        id: apiShowCostToggle
        visible: configPage.isApiMode
        Kirigami.FormData.label: i18n("Show cost:")
        text: i18n("Enabled")
    }

    PlasmaComponents.ComboBox {
        id: apiCurrencyCombo
        visible: configPage.isApiMode && apiShowCostToggle.checked
        Kirigami.FormData.label: i18n("Currency:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: "EUR (€)", value: "EUR" },
            { label: "USD ($)", value: "USD" }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_apiCurrency) { currentIndex = i; break }
            }
        }
    }

    PlasmaComponents.TextField {
        id: budgetCapField
        visible: configPage.isApiMode
        Kirigami.FormData.label: i18n("Manual cap:")
        placeholderText: i18n("e.g. 20.00 (leave empty for none)")
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        PlasmaComponents.ToolTip.text: i18n("Local widget cap only. This is not your Anthropic Console spend limit.")
        PlasmaComponents.ToolTip.visible: hovered
        Component.onCompleted: text = cfg_apiBudgetCap > 0 ? Number(cfg_apiBudgetCap).toFixed(2) : ""
        onTextChanged: {
            var v = parseFloat(text)
            budgetCapValue.value = (isNaN(v) || v <= 0) ? 0 : v
        }
    }

    PlasmaComponents.ComboBox {
        id: apiBudgetModeCombo
        visible: configPage.isApiMode
        Kirigami.FormData.label: i18n("Cap countdown:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: i18n("Selected window"), value: "selected" },
            { label: i18n("None"),            value: "none"     }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_apiBudgetMode) { currentIndex = i; break }
            }
        }
    }

    PlasmaComponents.ComboBox {
        id: apiRingDisplayCombo
        visible: configPage.isApiMode && configPage.isApiMode
        Kirigami.FormData.label: i18n("Ring shows:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: i18n("Spent (% of cap)"), value: "spent" },
            { label: i18n("Remaining budget"), value: "remaining" }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_apiRingDisplay) { currentIndex = i; break }
            }
        }
    }

    // ── Color theme (shared) ──────────────────────────────────────────────────
    PlasmaComponents.CheckBox {
        id: followPlasmaThemeToggle
        Kirigami.FormData.label: i18n("Follow Plasma Theme:")
        text: i18n("Switch with Plasma light/dark mode")
    }

    PlasmaComponents.ComboBox {
        id: themeCombo
        visible: !followPlasmaThemeToggle.checked
        Kirigami.FormData.label: i18n("Color theme:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: "Amber (Claude)", value: "amber"   },
            { label: "Ocean",          value: "ocean"   },
            { label: "Aurora",         value: "aurora"  },
            { label: "Violet",         value: "violet"  },
            { label: "Liquid Glass",   value: "glass"   },
            { label: "Emerald",        value: "emerald" },
            { label: "Rose",           value: "rose"    },
            { label: i18n("Custom…"),  value: "custom"  }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_colorTheme) { currentIndex = i; break }
            }
        }
    }

    PlasmaComponents.ComboBox {
        id: lightThemeCombo
        visible: followPlasmaThemeToggle.checked
        Kirigami.FormData.label: i18n("Light mode theme:")
        textRole: "label"
        valueRole: "value"
        model: themeCombo.model
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_lightModeTheme) { currentIndex = i; break }
            }
        }
    }

    PlasmaComponents.ComboBox {
        id: darkThemeCombo
        visible: followPlasmaThemeToggle.checked
        Kirigami.FormData.label: i18n("Dark mode theme:")
        textRole: "label"
        valueRole: "value"
        model: themeCombo.model
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_darkModeTheme) { currentIndex = i; break }
            }
        }
    }

    KQuickControls.ColorButton {
        id: sessionColorBtn
        Kirigami.FormData.label: i18n("Session color:")
        visible: !followPlasmaThemeToggle.checked && themeCombo.currentValue === "custom"
        showAlphaChannel: false
        Component.onCompleted: color = configRoot.cfg_customSessionColor
        onColorChanged: configRoot.cfg_customSessionColor = color.toString()
    }

    KQuickControls.ColorButton {
        id: weeklyColorBtn
        Kirigami.FormData.label: i18n("Weekly color:")
        visible: !followPlasmaThemeToggle.checked && themeCombo.currentValue === "custom"
        showAlphaChannel: false
        Component.onCompleted: color = configRoot.cfg_customWeeklyColor
        onColorChanged: configRoot.cfg_customWeeklyColor = color.toString()
    }

    // ── View (Claude.ai mode only) ────────────────────────────────────────────
    PlasmaComponents.CheckBox {
        id: minimalToggle
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("View (Desktop):")
        text: i18n("Rings & numbers only")
    }

    PlasmaComponents.CheckBox {
        id: desktopShortcutsToggle
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Desktop shortcuts:")
        text: i18n("Show below rings")
    }

    PlasmaComponents.ComboBox {
        id: sidebarViewCombo
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Sidebar view:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: i18n("Compact  (ring + shortcuts)"), value: "compact" },
            { label: i18n("Full widget  (scales to width)"), value: "full" },
            { label: i18n("Ring only"), value: "ring" }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_sidebarView) { currentIndex = i; break }
            }
        }
    }

    // ── Appearance ────────────────────────────────────────────────────────────
    PlasmaComponents.Slider {
        id: widgetOpacitySlider
        Kirigami.FormData.label: i18n("Widget opacity:")
        from: 0.1; to: 1.0; stepSize: 0.05
        PlasmaComponents.ToolTip { text: Math.round(widgetOpacitySlider.value * 100) + "%" }
    }

    PlasmaComponents.Slider {
        id: opacitySlider
        Kirigami.FormData.label: i18n("Background opacity:")
        from: 0.0; to: 1.0; stepSize: 0.05
        PlasmaComponents.ToolTip { text: Math.round(opacitySlider.value * 100) + "%" }
    }

    // ── Terminal (Claude.ai mode only) ────────────────────────────────────────
    PlasmaComponents.TextField {
        id: terminalField
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Terminal app:")
        placeholderText: i18n("e.g. konsole, kitty, alacritty")
    }

    // ── Auto-refresh ──────────────────────────────────────────────────────────
    PlasmaComponents.CheckBox {
        id: timerToggle
        Kirigami.FormData.label: i18n("Auto-refresh:")
        text: i18n("Enabled")
    }

    Row {
        Kirigami.FormData.label: i18n("Interval:")
        spacing: 6

        PlasmaComponents.ComboBox {
            id: intervalCombo
            enabled: timerToggle.checked
            textRole: "label"
            valueRole: "value"
            model: [
                { label: i18n("2 minutes"),  value: 120 },
                { label: i18n("5 minutes"),  value: 300 },
                { label: i18n("10 minutes"), value: 600 },
                { label: i18n("30 minutes"), value: 1800 },
                { label: i18n("1 hour"),     value: 3600 },
                { label: i18n("2 hours"),    value: 7200 },
                { label: i18n("6 hours"),    value: 21600 }
            ]
            Component.onCompleted: {
                var matched = false
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === cfg_refreshIntervalSeconds) {
                        currentIndex = i
                        matched = true
                        break
                    }
                }
                if (!matched) {
                    currentIndex = 0
                    cfg_refreshIntervalSeconds = model[0].value
                }
            }
        }

        PlasmaComponents.Label {
            id: refreshInfoLabel
            text: i18n("(i)")
            color: Kirigami.Theme.disabledTextColor
            font.bold: true

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            PlasmaComponents.ToolTip.text: i18n("Anthropic can rate-limit frequent refreshes. Sorry about that. API mode now starts at 2 minutes to avoid unnecessary blocks.")
            PlasmaComponents.ToolTip.visible: refreshInfoLabel.children[0].containsMouse
        }
    }

    // ── Project shortcut (Claude.ai mode only) ────────────────────────────────
    PlasmaComponents.TextField {
        id: projectLabelField
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Project shortcut:")
        placeholderText: i18n("Name (e.g. My Project)")
    }

    PlasmaComponents.TextField {
        id: projectUrlField
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Project URL:")
        placeholderText: "https://claude.ai/project/..."
    }

    // ── Script path (advanced) ────────────────────────────────────────────────
    PlasmaComponents.TextField {
        id: scriptPathField
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Script path:")
        placeholderText: i18n("Default: ~/.config/claude-widget/claude_usage.py")
    }

    // ── Notifications (Claude.ai mode only) ───────────────────────────────────
    PlasmaComponents.CheckBox {
        id: notifyAllToggle
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Notifications:")
        text: i18n("All")
        tristate: true
        checkState: {
            var all = [notifyS25, notifyS50, notifyS80, notifyS95,
                       notifyW25, notifyW50, notifyW80, notifyW95]
            var on = all.filter(function(c){ return c.checked }).length
            return on === 0 ? Qt.Unchecked : on === all.length ? Qt.Checked : Qt.PartiallyChecked
        }
        onClicked: {
            var val = (checkState !== Qt.Checked)
            notifyS25.checked = notifyS50.checked = notifyS80.checked = notifyS95.checked = val
            notifyW25.checked = notifyW50.checked = notifyW80.checked = notifyW95.checked = val
        }
    }

    Row {
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Session:")
        spacing: 12
        PlasmaComponents.CheckBox { id: notifyS25; text: "25%" }
        PlasmaComponents.CheckBox { id: notifyS50; text: "50%" }
        PlasmaComponents.CheckBox { id: notifyS80; text: "80%" }
        PlasmaComponents.CheckBox { id: notifyS95; text: "95%" }
    }

    Row {
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Weekly:")
        spacing: 12
        PlasmaComponents.CheckBox { id: notifyW25; text: "25%" }
        PlasmaComponents.CheckBox { id: notifyW50; text: "50%" }
        PlasmaComponents.CheckBox { id: notifyW80; text: "80%" }
        PlasmaComponents.CheckBox { id: notifyW95; text: "95%" }
    }

    } // Kirigami.FormLayout

    // ── Buy me a coffee — anchored to bottom-right of the config window ───────
    Image {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.margins: 12
        width: 70
        height: 70
        source: Qt.resolvedUrl("../icons/bmc_qr.png")
        smooth: true
        opacity: 0.75

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("https://buymeacoffee.com/02nmd")
        }
        PlasmaComponents.ToolTip { text: "Buy me a coffee ☕" }
    }

} // Item (root)
