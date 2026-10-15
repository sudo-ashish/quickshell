import QtQuick
import "../theme"

Item {
    id: root

    property int value: 50
    property int from: 0
    property int to: 100
    property string icon: ""
    property string suffix: "%"
    property color fillColor: Theme.accent

    signal moved(int val)

    implicitWidth: 260
    implicitHeight: 34

    Row {
        id: layoutRow
        anchors.fill: parent
        spacing: 10

        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            id: trackContainer
            width: parent.width - (root.icon.length > 0 ? 30 : 0) - 45
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            // Track background
            Rectangle {
                id: trackBg
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                radius: 4
                color: Theme.selection

                // Filled portion
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(parent.width, parent.width * ((root.value - root.from) / (root.to - root.from))))
                    radius: 4
                    color: root.fillColor
                }
            }

            // Knob
            Rectangle {
                id: knob
                x: Math.max(0, Math.min(trackBg.width - width, (trackBg.width * ((root.value - root.from) / (root.to - root.from))) - (width / 2)))
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: Theme.foreground
                border.color: Theme.accent
                border.width: 2

                scale: sliderMouse.containsMouse || sliderMouse.pressed ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function updateFromPos(mouseX) {
                    var pct = Math.max(0, Math.min(1.0, mouseX / trackBg.width))
                    var newVal = Math.round(root.from + (pct * (root.to - root.from)))
                    root.value = newVal
                    root.moved(newVal)
                }

                onPressed: function(mouse) { updateFromPos(mouse.x) }
                onPositionChanged: function(mouse) {
                    if (pressed) updateFromPos(mouse.x)
                }
            }
        }

        Text {
            text: root.value + root.suffix
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.foreground
            width: 35
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
