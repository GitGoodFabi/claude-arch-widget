import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: configPage

    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_terminalApp: terminalField.text
    property alias cfg_refreshInterval: refreshSpinBox.value

    PlasmaComponents.Slider {
            id: opacitySlider
            Kirigami.FormData.label: "Hintergrund-Deckkraft:"
            from: 0.0; to: 1.0; stepSize: 0.05
            PlasmaComponents.ToolTip {
                text: Math.round(opacitySlider.value * 100) + "%"
            }
        }

    PlasmaComponents.TextField {
            id: terminalField
            Kirigami.FormData.label: "Terminal-App:"
            placeholderText: "z.B. konsole, kitty, alacritty"
        }

    PlasmaComponents.SpinBox {
            id: refreshSpinBox
            Kirigami.FormData.label: "Auto-Refresh:"
            from: 1; to: 60; stepSize: 1
            textFromValue: function(val, locale) { return val + " min" }
            valueFromText: function(text, locale) { return parseInt(text) }
        }
}
