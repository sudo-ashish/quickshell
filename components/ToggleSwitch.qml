import QtQuick
import "../theme"

Item {
    id: root

    property bool checked: false
    property bool interactive: true
    signal toggled()

    implicitWidth: Appearance.toggleTrackWidth
    implicitHeight: Appearance.toggleTrackHeight
    width: implicitWidth
    height: implicitHeight

    // Rectangular Toggle Switch matching Speaker switch
    Rectangle {
        id: track
        width: Appearance.toggleTrackWidth
        height: Appearance.toggleTrackHeight
        radius: Appearance.toggleTrackRadius
        anchors.centerIn: parent
        color: root.checked ? Theme.selection : Theme.dark_background
        border.color: Theme.selection
        border.width: Appearance.toggleBorderWidth

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            id: thumb
            width: Appearance.toggleThumbSize
            height: Appearance.toggleThumbSize
            radius: Appearance.toggleThumbRadius
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
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
