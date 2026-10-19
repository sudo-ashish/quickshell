import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../components"
import "../services"

Item {
    id: root

    required property BrightnessService service

    property int iconSize: Appearance.monitorIconSize

    implicitWidth: monButton.implicitWidth
    implicitHeight: monButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: monButton
        icon: root.service.icon
        iconSize: root.iconSize
        accentActive: false
        active: monPopup.open
        onClicked: {
            root.toggle()
        }
    }

    function toggle() {
        monPopup.toggle()
        if (monPopup.open) root.service.refresh()
    }

    Connections {
        target: monPopup
        function onOpenChanged() {
            root.service.menuOpen = monPopup.open
            if (monPopup.open) {
                root.service.inhibitOsd(2500)
            } else {
                root.service.inhibitOsd(1500)
            }
        }
    }

    PopupCard {
        id: monPopup
        anchorItem: monButton
        showDefaultHeader: false
        contentWidth: 350
        contentHeight: mainCol.implicitHeight + 24

        Column {
            id: mainCol
            anchors.fill: parent
            spacing: 12

            // --- 1. Header (Display Icon + Name + Percentage) ---
            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text {
                        text: "󰍹"
                        font.family: Icons.effectiveFont("󰍹")
                        font.pixelSize: 26
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Display"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeLarge
                            font.bold: true
                            color: Theme.foreground
                        }

                        Text {
                            text: root.service.brightnessName || "Internal Display"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.muted
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
            }

            // --- 2. BRIGHTNESS Section ---
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "BRIGHTNESS"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service.brightness + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.foreground
                    }
                }

                // Continuous Slider
                Item {
                    id: brightSliderItem
                    width: parent.width
                    height: 24

                    Rectangle {
                        id: bTrack
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: Appearance.radiusXs
                        color: Theme.selection

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.service.brightness / 100.0)))
                            radius: Appearance.radiusXs
                            color: Theme.accent

                            Behavior on width {
                                enabled: !bMouse.pressed
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Rectangle {
                        id: bKnob
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.bright_foreground
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(brightSliderItem.width - width, (brightSliderItem.width * (root.service.brightness / 100.0)) - (width / 2)))

                        scale: bMouse.containsMouse || bMouse.pressed ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Behavior on x {
                            enabled: !bMouse.pressed
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        id: bMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateFromPos(mouseX) {
                            root.service.inhibitOsd(2000)
                            var pct = Math.max(1, Math.min(100, Math.round((mouseX / brightSliderItem.width) * 100)))
                            root.service.setBrightness(pct)
                        }

                        onPressed: function(mouse) { updateFromPos(mouse.x) }
                        onPositionChanged: function(mouse) {
                            if (pressed) updateFromPos(mouse.x)
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
            }

            // --- 3. TEXT SIZE Section (Stepped Notch Slider) ---
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TEXT SIZE"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service.textSize + "px"
                        font.family: Fonts.monoFont
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.foreground
                    }
                }

                Item {
                    id: textSliderItem
                    width: parent.width
                    height: 24

                    readonly property var stops: root.service.textSizeStops
                    readonly property int activeIndex: {
                        var idx = stops.indexOf(root.service.textSize)
                        if (idx >= 0) return idx
                        var best = 0
                        var bestDiff = 1e9
                        for (var i = 0; i < stops.length; i++) {
                            var d = Math.abs(stops[i] - root.service.textSize)
                            if (d < bestDiff) {
                                bestDiff = d
                                best = i
                            }
                        }
                        return best
                    }

                    // Stepped Segments Track
                    Row {
                        anchors.fill: parent
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 4

                        Repeater {
                            model: textSliderItem.stops.length - 1

                            Rectangle {
                                required property int index
                                width: (textSliderItem.width - (4 * (textSliderItem.stops.length - 2))) / (textSliderItem.stops.length - 1)
                                height: 4
                                radius: Appearance.radiusXs
                                color: (index < textSliderItem.activeIndex) ? Theme.accent : Theme.selection
                            }
                        }
                    }

                    // Stepped Knob Handle
                    Rectangle {
                        id: tKnob
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.bright_foreground
                        anchors.verticalCenter: parent.verticalCenter
                        x: {
                            var count = textSliderItem.stops.length
                            if (count <= 1) return 0
                            var ratio = textSliderItem.activeIndex / (count - 1)
                            return Math.max(0, Math.min(textSliderItem.width - width, (ratio * (textSliderItem.width - width))))
                        }

                        scale: tMouse.containsMouse || tMouse.pressed ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }
                    }

                    MouseArea {
                        id: tMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateFromPos(mouseX) {
                            var count = textSliderItem.stops.length
                            var ratio = Math.max(0, Math.min(1.0, mouseX / textSliderItem.width))
                            var nearestIndex = Math.round(ratio * (count - 1))
                            var newSize = textSliderItem.stops[nearestIndex]
                            if (newSize !== root.service.textSize) {
                                root.service.setTextSize(newSize)
                            }
                        }

                        onPressed: function(mouse) { updateFromPos(mouse.x) }
                        onPositionChanged: function(mouse) {
                            if (pressed) updateFromPos(mouse.x)
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
            }

            // --- 4. SCALE Section (Segmented Pill Buttons) ---
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SCALE"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Text {
                        visible: root.service.displays.length > 1
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service.focusedMonitor
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.dark_foreground
                    }
                }

                Row {
                    id: scaleRow
                    width: parent.width
                    spacing: 6

                    readonly property int count: root.service.scalePresets.length
                    readonly property real pillWidth: (width - (spacing * (count - 1))) / count

                    Repeater {
                        model: root.service.scalePresets

                        Rectangle {
                            id: scalePill
                            required property string modelData
                            required property int index

                            readonly property bool isActive: {
                                var cur = parseFloat(root.service.scale)
                                var tgt = parseFloat(modelData)
                                return !isNaN(cur) && !isNaN(tgt) && Math.abs(cur - tgt) < 0.05
                            }

                            width: scaleRow.pillWidth
                            height: 28
                            radius: Appearance.radiusSmall
                            color: isActive ? Theme.selection : (pillMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)
                            border.color: isActive ? Theme.accent : Theme.selection
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: scalePill.modelData + "x"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: scalePill.isActive 
                                color: scalePill.isActive ? Theme.accent : Theme.foreground
                            }

                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.service.setScale(scalePill.modelData)
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
            }

            // --- 5. REFRESH RATE Section (Segmented Pill Buttons) ---
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REFRESH RATE"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            visible: root.service.displays.length > 1
                            text: root.service.activeMonitorName
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            color: Theme.dark_foreground
                        }

                        Text {
                            text: root.service.currentRefreshRate + "Hz"
                            font.family: Fonts.monoFont
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.foreground
                        }
                    }
                }

                Row {
                    id: hzRow
                    width: parent.width
                    spacing: 6

                    readonly property int maxHz: root.service.maxRefreshRate
                    readonly property bool canSwitch: maxHz > 60

                    // 60 Hz Pill
                    Rectangle {
                        id: hz60Pill
                        width: hzRow.canSwitch ? (hzRow.width - hzRow.spacing) / 2 : hzRow.width
                        height: 28
                        radius: Appearance.radiusSmall

                        readonly property bool isActive: Math.abs(root.service.currentRefreshRate - 60) <= 2

                        color: isActive ? Theme.selection : (p60Mouse.containsMouse ? Theme.lighter_background : Theme.dark_background)
                        border.color: isActive ? Theme.accent : Theme.selection
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "60 Hz" + (hzRow.canSwitch ? "" : " (Max)")
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: hz60Pill.isActive 
                            color: hz60Pill.isActive ? Theme.accent : Theme.foreground
                        }

                        MouseArea {
                            id: p60Mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.setRefreshRate(60)
                        }
                    }

                    // Max Hz Pill (shown if maxHz > 60)
                    Rectangle {
                        id: hzMaxPill
                        visible: hzRow.canSwitch
                        width: (hzRow.width - hzRow.spacing) / 2
                        height: 28
                        radius: Appearance.radiusSmall

                        readonly property bool isActive: Math.abs(root.service.currentRefreshRate - hzRow.maxHz) <= 2

                        color: isActive ? Theme.selection : (pMaxMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)
                        border.color: isActive ? Theme.accent : Theme.selection
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: hzRow.maxHz + " Hz (Max)"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: hzMaxPill.isActive 
                            color: hzMaxPill.isActive ? Theme.accent : Theme.foreground
                        }

                        MouseArea {
                            id: pMaxMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.setRefreshRate(hzRow.maxHz)
                        }
                    }
                }
            }

            // --- 6. Displays (shown if multiple monitors exist) ---
            Column {
                visible: root.service.displays.length > 1
                width: parent.width
                spacing: 6

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.selection
                }

                Text {
                    text: "DISPLAYS"
                    font.family: Fonts.uiFont
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.muted
                }

                Repeater {
                    model: root.service.displays

                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 32
                        radius: Appearance.radiusSmall
                        color: modelData.focused ? Theme.selection : (dispMouse.containsMouse ? Theme.lighter_background : "transparent")
                        border.width: modelData.focused ? 1 : 0
                        border.color: modelData.focused ? Theme.accent : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "󰍹"
                                font.family: Icons.effectiveFont("󰍹")
                                font.pixelSize: 14
                                color: modelData.focused ? Theme.accent : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.name + (modelData.focused ? " · active" : "") + " (" + modelData.refreshRate + "Hz)"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: modelData.focused 
                                color: modelData.focused ? Theme.foreground : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: dispMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.selectDisplay(modelData.name)
                        }
                    }
                }
            }
        }
    }
}
