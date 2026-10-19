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

    implicitWidth: Appearance.sliderWidth
    implicitHeight: Appearance.sliderHeight

    Row {
        id: layoutRow
        anchors.fill: parent
        spacing: Appearance.sliderSpacing

        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Icons.effectiveFont(root.icon)
            font.pixelSize: Fonts.sizeMedium
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
                height: Appearance.sliderTrackHeight
                radius: Appearance.sliderTrackRadius
                color: Theme.selection

                // Filled portion
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(parent.width, parent.width * ((root.value - root.from) / (root.to - root.from))))
                    radius: Appearance.sliderTrackRadius
                    color: root.fillColor
                }
            }

            // Knob
            Rectangle {
                id: knob
                x: Math.max(0, Math.min(trackBg.width - width, (trackBg.width * ((root.value - root.from) / (root.to - root.from))) - (width / 2)))
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.sliderKnobSize
                height: Appearance.sliderKnobSize
                radius: Appearance.sliderKnobRadius
                color: Theme.foreground
                border.color: Theme.accent
                border.width: Appearance.sliderKnobBorderWidth

                scale: sliderMouse.containsMouse || sliderMouse.pressed ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: Appearance.animDurationFast } }
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
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.sizeSmall
            color: Theme.foreground
            width: 35
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
