import QtQuick
import "../theme"

Item {
    id: root

    property bool checked: false
    property bool interactive: true
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    width: implicitWidth
    height: implicitHeight

    // Rectangular Toggle Switch matching Speaker switch
    Rectangle {
        id: track
        width: 40
        height: 22
        radius: 2
        anchors.centerIn: parent
        color: root.checked ? Theme.selection : Theme.dark_background
        border.color: Theme.selection
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            id: thumb
            width: 16
            height: 16
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? (track.width - width - 3) : 3
            color: root.checked ? Theme.accent : Theme.muted

            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
