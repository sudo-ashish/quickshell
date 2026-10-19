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
    property int customPadding: Appearance.buttonPadding
    property int iconSize: Icons.sizeNormal
    property int textSize: Fonts.sizeRegular

    signal clicked()

    implicitWidth: Math.max(Appearance.barButtonHeight, contentRow.implicitWidth + (customPadding * 2))
    implicitHeight: Appearance.barButtonHeight
    width: implicitWidth
    height: implicitHeight
    radius: Appearance.buttonRadius

    color: {
        if (active) return Theme.selection
        if (mouseArea.containsMouse) return Theme.lighter_background
        return "transparent"
    }

    Behavior on color {
        ColorAnimation { duration: Appearance.animDurationNormal }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Appearance.spacingMedium - 2 // 6px

        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Icons.effectiveFont(root.icon)
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
            font.family: Fonts.uiFont
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
        height: Appearance.borderWidthMedium
        radius: Appearance.borderWidthThin
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
