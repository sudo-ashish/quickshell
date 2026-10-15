import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

Item {
    id: root

    // Visual properties matching centralized theme
    property color surfaceColor: Theme.withAlpha(Theme.background, Theme.baseOpacity)
    property color borderColor: "transparent"
    property int borderWidth: 0
    property int surfaceRadius: 10

    // Exposed reference to the visual container
    readonly property Item surfaceContainer: backgroundRect
    readonly property int cornerRadius: surfaceRadius

    // Default property allows child items placed inside ShellSurface to be reparented into contentContainer
    default property alias content: contentContainer.data

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        radius: root.surfaceRadius
        color: root.surfaceColor
        border.color: root.borderColor
        border.width: root.borderWidth

        Item {
            id: contentContainer
            anchors.fill: parent
        }
    }
}
