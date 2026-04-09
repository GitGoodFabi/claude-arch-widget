import QtQuick
import org.kde.kirigami as Kirigami

Item {
    property real pct: 0
    width: parent ? parent.width : 200
    height: 6

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.separatorColor
        border.width: 1
    }

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }
        width: Math.max(radius * 2, parent.width * Math.min(pct, 100) / 100)
        radius: 3
        color: {
            if (pct >= 90) return Kirigami.Theme.negativeTextColor
            if (pct >= 70) return Kirigami.Theme.neutralTextColor
            return Kirigami.Theme.positiveTextColor
        }
        Behavior on width { NumberAnimation { duration: 300 } }
    }
}
