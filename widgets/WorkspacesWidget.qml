import QtQuick
import "../theme"
import "../services"

Row {
    id: root

    required property WorkspacesService service

    spacing: 2
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
        model: root.service.workspaceIds

        Rectangle {
            id: wsBtn
            required property int modelData

            readonly property bool isActive: root.service.activeWorkspaceId === modelData
            readonly property bool isOccupied: !!root.service.occupiedWorkspaces[modelData]

            width: 24
            height: 24
            radius: Theme.radiusSmall

            color: {
                if (isActive) return Theme.selection
                if (wsMouse.containsMouse) return Theme.lighter_background
                return "transparent"
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.centerIn: parent
                // If active, show filled block symbol ■ (like running machine!) else number
                text: wsBtn.isActive ? "" : String(wsBtn.modelData)
                font.family: Theme.fontFamily
                font.pixelSize: wsBtn.isActive ? Theme.fontSizeMedium : Theme.fontSizeRegular
                font.bold: wsBtn.isActive
                color: {
                    if (wsBtn.isActive) return Theme.accent
                    if (wsBtn.isOccupied) return Theme.foreground
                    return Theme.muted
                }
                opacity: (wsBtn.isActive || wsBtn.isOccupied) ? 1.0 : 0.5
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.service.switchTo(wsBtn.modelData)
            }
        }
    }
}
