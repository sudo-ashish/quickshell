import QtQuick
import Quickshell
import "../theme"

Rectangle {
    id: root

    readonly property var window: QsWindow.window

    property string icon: ""
    property string text: ""
    property bool active: false
    property bool accentActive: false
    property color customColor: "transparent"
    property int customPadding: 8
    property int iconSize: Theme.fontSizeLarge
    property int textSize: Theme.fontSizeRegular

    signal clicked()

    implicitWidth: Math.max(Theme.barHeight - 4, contentRow.implicitWidth + (customPadding * 2))
    implicitHeight: Theme.barHeight - 4
    width: implicitWidth
    height: implicitHeight
    radius: Theme.radiusSmall

    color: {
        if (active) return Theme.selection
        if (mouseArea.containsMouse) return Theme.lighter_background
        return "transparent"
    }

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: root.iconSize
            color: {
                if (root.accentActive || root.active) return Theme.accent
                if (root.customColor.a > 0) return root.customColor
                return Theme.foreground
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: root.textSize
            font.bold: root.active
            color: root.active ? Theme.accent : Theme.foreground
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Active bottom indicator line
    Rectangle {
        visible: root.active
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 4, 16)
        height: 2
        radius: 1
        color: Theme.accent
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
