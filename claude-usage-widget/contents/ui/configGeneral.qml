import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: configPage

    property alias cfg_colorTheme: themeCombo.currentValue
    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_terminalApp: terminalField.text
    property alias cfg_timerEnabled: timerToggle.checked
    property alias cfg_refreshIntervalSeconds: intervalCombo.currentValue
    property alias cfg_projectShortcutLabel: projectLabelField.text
    property alias cfg_projectShortcutUrl: projectUrlField.text
    property alias cfg_minimalView: minimalToggle.checked
    property alias cfg_sidebarShortcuts: sidebarShortcutsToggle.checked

    // ── Farbthema ─────────────────────────────────────────────────────────
    PlasmaComponents.ComboBox {
        id: themeCombo
        Kirigami.FormData.label: i18n("Color theme:")
        textRole: "label"
        valueRole: "value"
        model: [
            { label: "Amber",         value: "amber"  },
            { label: "Ocean",         value: "ocean"  },
            { label: "Aurora",        value: "aurora" },
            { label: "Violet",        value: "violet" },
            { label: "Liquid Glass",  value: "glass"  }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === cfg_colorTheme) {
                    currentIndex = i; break
                }
            }
        }
    }

    // ── Ansicht ───────────────────────────────────────────────────────────
    PlasmaComponents.CheckBox {
        id: minimalToggle
        Kirigami.FormData.label: i18n("View (Desktop):")
        text: i18n("Rings & numbers only")
    }

    PlasmaComponents.CheckBox {
        id: sidebarShortcutsToggle
        Kirigami.FormData.label: i18n("Sidebar shortcuts:")
        text: i18n("Show below rings")
    }

    // ── Aussehen ──────────────────────────────────────────────────────────
    PlasmaComponents.Slider {
        id: opacitySlider
        Kirigami.FormData.label: i18n("Background opacity:")
        from: 0.0; to: 1.0; stepSize: 0.05
        PlasmaComponents.ToolTip {
            text: Math.round(opacitySlider.value * 100) + "%"
        }
    }

    // ── Terminal ─────────────────────────────────────────────────────────
    PlasmaComponents.TextField {
        id: terminalField
        Kirigami.FormData.label: i18n("Terminal app:")
        placeholderText: i18n("e.g. konsole, kitty, alacritty")
    }

    // ── Auto-Refresh ─────────────────────────────────────────────────────
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
                if (model[i].value === cfg_refreshIntervalSeconds) {
                    currentIndex = i
                    break
                }
            }
        }
    }

    // ── Projekt-Shortcut ─────────────────────────────────────────────────
    PlasmaComponents.TextField {
        id: projectLabelField
        Kirigami.FormData.label: i18n("Project shortcut:")
        placeholderText: i18n("Name (e.g. My Project)")
    }

    PlasmaComponents.TextField {
        id: projectUrlField
        Kirigami.FormData.label: i18n("Project URL:")
        placeholderText: "https://claude.ai/project/..."
    }
}
