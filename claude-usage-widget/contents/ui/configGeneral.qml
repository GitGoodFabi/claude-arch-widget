import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    id: configPage

    // ── Mode ──────────────────────────────────────────────────────────────────
    property alias cfg_widgetMode:    modeCombo.currentValue
    property string cfg_apiKey:       ""
    property alias cfg_apiTimeWindow: apiWindowCombo.currentValue
    property alias cfg_apiShowCost:   apiShowCostToggle.checked
    property alias cfg_apiCurrency:   apiCurrencyCombo.currentValue
    property double cfg_apiBudgetCap: 0

    // ── Appearance & Claude.ai settings ──────────────────────────────────────
    property alias cfg_colorTheme:            themeCombo.currentValue
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
    property alias cfg_sidebarShortcuts:      sidebarShortcutsToggle.checked
    property alias cfg_desktopShortcuts:      desktopShortcutsToggle.checked
    property alias cfg_scriptPath:            scriptPathField.text
    property alias cfg_notifySession25: notifyS25.checked
    property alias cfg_notifySession50: notifyS50.checked
    property alias cfg_notifySession80: notifyS80.checked
    property alias cfg_notifySession95: notifyS95.checked
    property alias cfg_notifyWeekly25:  notifyW25.checked
    property alias cfg_notifyWeekly50:  notifyW50.checked
    property alias cfg_notifyWeekly80:  notifyW80.checked
    property alias cfg_notifyWeekly95:  notifyW95.checked

    readonly property bool isApiMode: modeCombo.currentValue === "api"

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

    // ── API settings (visible in API mode only) ───────────────────────────────
    PlasmaComponents.TextField {
        id: apiKeyField
        visible: configPage.isApiMode
        Kirigami.FormData.label: i18n("Admin API key:")
        placeholderText: "sk-ant-admin-..."
        echoMode: TextInput.Password
        Component.onCompleted: text = configPage.cfg_apiKey
        onTextChanged: configPage.cfg_apiKey = text
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
            { label: i18n("Monthly"), value: "monthly" }
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
        Kirigami.FormData.label: i18n("Budget cap:")
        placeholderText: i18n("e.g. 20.00 (leave empty for no cap)")
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        Component.onCompleted: text = cfg_apiBudgetCap > 0 ? cfg_apiBudgetCap.toFixed(2) : ""
        onEditingFinished: {
            var v = parseFloat(text)
            configPage.cfg_apiBudgetCap = (isNaN(v) || v <= 0) ? 0 : v
        }
    }

    // ── Color theme (shared) ──────────────────────────────────────────────────
    PlasmaComponents.ComboBox {
        id: themeCombo
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

    KQuickControls.ColorButton {
        id: sessionColorBtn
        Kirigami.FormData.label: i18n("Session color:")
        visible: themeCombo.currentValue === "custom"
        showAlphaChannel: false
        Component.onCompleted: color = configPage.cfg_customSessionColor
        onColorChanged: configPage.cfg_customSessionColor = color.toString()
    }

    KQuickControls.ColorButton {
        id: weeklyColorBtn
        Kirigami.FormData.label: i18n("Weekly color:")
        visible: themeCombo.currentValue === "custom"
        showAlphaChannel: false
        Component.onCompleted: color = configPage.cfg_customWeeklyColor
        onColorChanged: configPage.cfg_customWeeklyColor = color.toString()
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

    PlasmaComponents.CheckBox {
        id: sidebarShortcutsToggle
        visible: !configPage.isApiMode
        Kirigami.FormData.label: i18n("Sidebar shortcuts:")
        text: i18n("Show below rings")
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

    PlasmaComponents.ComboBox {
        id: intervalCombo
        Kirigami.FormData.label: i18n("Interval:")
        enabled: timerToggle.checked
        textRole: "label"
        valueRole: "value"
        model: [
            { label: i18n("5 seconds"),  value: 5   },
            { label: i18n("30 seconds"), value: 30  },
            { label: i18n("2 minutes"),  value: 120 },
            { label: i18n("5 minutes"),  value: 300 },
            { label: i18n("10 minutes"), value: 600 }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_refreshIntervalSeconds) { currentIndex = i; break }
            }
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
}
