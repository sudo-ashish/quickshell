import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../components"
import "../services"
import "../services/AudioModel.js" as Model

Item {
    id: root

    required property AudioService service

    property int iconSize: Appearance.audioIconSize

    implicitWidth: audioButton.implicitWidth
    implicitHeight: audioButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function toggle() {
        audioPopup.toggle()
        if (audioPopup.open) root.service.refresh()
    }

    BarButton {
        id: audioButton
        icon: root.service.icon
        iconSize: root.iconSize
        accentActive: root.service.volume > 0 && !root.service.muted
        customColor: root.service.muted ? Theme.red : Theme.foreground
        active: audioPopup.open
        onClicked: {
            audioPopup.toggle()
            if (audioPopup.open) root.service.refresh()
        }
    }

    Connections {
        target: root.service
        function onRequestToggleMenu() {
            audioPopup.toggle()
            if (audioPopup.open) root.service.refresh()
        }
    }

    Connections {
        target: audioPopup
        function onOpenChanged() {
            root.service.menuOpen = audioPopup.open
            if (audioPopup.open) {
                root.service.inhibitOsd(2500)
            } else {
                root.service.inhibitOsd(1500)
            }
        }
    }

    // High-performance, zero-latency slider
    component AudioSlider: Item {
        id: sliderRoot
        property real value: 0
        property real liveValue: value
        property real from: 0
        property real to: 100
        property bool muted: false
        property bool dragging: false

        onValueChanged: {
            if (!dragging) liveValue = value
        }

        signal moved(real val)
        signal rightClicked()

        implicitWidth: parent ? parent.width : 290
        implicitHeight: Appearance.audioSliderHeight
        height: Appearance.audioSliderHeight

        readonly property real range: Math.max(0.001, to - from)
        readonly property real progress: Math.max(0.0, Math.min(1.0, (liveValue - from) / range))

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Appearance.audioSliderTrackHeight
            radius: Appearance.audioSliderTrackRadius
            color: Theme.selection

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * sliderRoot.progress
                radius: Appearance.audioSliderTrackRadius
                color: sliderRoot.muted ? Theme.muted : Theme.accent

                Behavior on width {
                    enabled: !sliderRoot.dragging
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        Rectangle {
            id: knob
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: track.verticalCenter
            x: Math.max(0, Math.min(track.width - width, track.width * sliderRoot.progress - width / 2))
            color: sliderRoot.muted ? Theme.muted : Theme.bright_foreground

            scale: sliderMouse.containsMouse || sliderRoot.dragging ? 1.2 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Behavior on x {
                enabled: !sliderRoot.dragging
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            function updateFromMouse(mouseX) {
                root.service.inhibitOsd(2000)
                var p = Math.max(0.0, Math.min(1.0, mouseX / track.width))
                var newVal = sliderRoot.from + (p * sliderRoot.range)
                sliderRoot.liveValue = newVal
                sliderRoot.moved(newVal)
            }

            onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    sliderRoot.dragging = true
                    updateFromMouse(mouse.x)
                }
            }
            onPositionChanged: function(mouse) {
                if (sliderRoot.dragging && (mouse.buttons & Qt.LeftButton)) {
                    updateFromMouse(mouse.x)
                }
            }
            onReleased: function(mouse) {
                if (sliderRoot.dragging) {
                    sliderRoot.dragging = false
                    sliderRoot.liveValue = sliderRoot.value
                }
            }
            onCanceled: {
                sliderRoot.dragging = false
                sliderRoot.liveValue = sliderRoot.value
            }
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) sliderRoot.rightClicked()
            }
        }
    }

    PopupCard {
        id: audioPopup
        anchorItem: audioButton
        showDefaultHeader: false
        contentWidth: 330
        contentHeight: audioCol.implicitHeight + 24

        Column {
            id: audioCol
            anchors.fill: parent
            spacing: 12

            // ================= 1. HERO HEADER =================
            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text {
                        text: root.service.muted ? "󰝟" : "󰕾"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 24
                        color: root.service.muted ? Theme.muted : Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Audio"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeMedium
                            font.bold: true
                            color: Theme.foreground
                        }

                        Text {
                            text: root.service.volumeName.toUpperCase()
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.1
                            color: Theme.muted
                        }
                    }
                }

                // Rectangular Toggle Switch
                ToggleSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.service.anyAudible
                    onToggled: root.service.toggleAllMuted()
                }
            }

            // Hairline Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
            }

            // ================= 2. OUTPUT SECTION =================
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "OUTPUT"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service.muted ? "MUTED" : (Math.round(outSlider.liveValue) + "%")
                        font.family: Fonts.monoFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.foreground
                    }
                }

                AudioSlider {
                    id: outSlider
                    width: parent.width
                    from: 0
                    to: 100
                    value: root.service.volume
                    muted: root.service.muted
                    onMoved: function(v) { root.service.setVolume(v) }
                    onRightClicked: root.service.toggleMute()
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.service.sinks

                        Rectangle {
                            id: sinkBox
                            required property var modelData
                            width: parent.width
                            height: 34
                            radius: Appearance.radiusSmall
                            color: modelData.isDefault ? Theme.selection : (sinkMouse.containsMouse ? Theme.lighter_background : "transparent")
                            border.color: modelData.isDefault ? Theme.accent : "transparent"
                            border.width: 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Text {
                                    text: sinkBox.modelData.glyph
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 15
                                    color: Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: sinkBox.modelData.displayName
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 12
                                    font.bold: sinkBox.modelData.isDefault 
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                    width: parent.width - 32
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: sinkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.service.setDefaultSink(sinkBox.modelData.node)
                            }
                        }
                    }
                }
            }

            // Hairline Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
                visible: root.service.sources.length > 0 || root.service.source !== null
            }

            // ================= 3. INPUT SECTION =================
            Column {
                width: parent.width
                spacing: 8
                visible: root.service.sources.length > 0 || root.service.source !== null

                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INPUT"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service.inputMuted ? "MUTED" : (Math.round(inSlider.liveValue) + "%")
                        font.family: Fonts.monoFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.foreground
                    }
                }

                AudioSlider {
                    id: inSlider
                    width: parent.width
                    from: 0
                    to: 100
                    value: root.service.inputVolume
                    muted: root.service.inputMuted
                    onMoved: function(v) { root.service.setInputVolume(v) }
                    onRightClicked: root.service.toggleInputMute()
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.service.sources

                        Rectangle {
                            id: srcBox
                            required property var modelData
                            width: parent.width
                            height: 34
                            radius: Appearance.radiusSmall
                            color: modelData.isDefault ? Theme.selection : (srcMouse.containsMouse ? Theme.lighter_background : "transparent")
                            border.color: modelData.isDefault ? Theme.accent : "transparent"
                            border.width: 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Text {
                                    text: srcBox.modelData.glyph
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 15
                                    color: Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: srcBox.modelData.displayName
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 12
                                    font.bold: srcBox.modelData.isDefault 
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                    width: parent.width - 32
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: srcMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.service.setDefaultSource(srcBox.modelData.node)
                            }
                        }
                    }
                }
            }

            // Hairline Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
                visible: root.service.audioStreams.length > 0
            }

            // ================= 4. SOURCES SECTION =================
            Column {
                width: parent.width
                spacing: 8
                visible: root.service.audioStreams.length > 0

                Text {
                    text: "SOURCES"
                    font.family: Fonts.uiFont
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.muted
                }

                Repeater {
                    model: root.service.audioStreams

                    Rectangle {
                        id: streamCard
                        required property var modelData
                        readonly property var streamNode: modelData
                        readonly property real streamVolume: streamNode && streamNode.audio ? (streamNode.audio.volume * 100.0) : 0
                        readonly property bool streamMuted: streamNode && streamNode.audio ? streamNode.audio.muted : false
                        readonly property string streamName: Model.streamLabel(streamNode) || "App"

                        width: parent.width
                        height: 58
                        radius: Appearance.radiusSmall
                        color: Theme.dark_background
                        border.color: Theme.selection
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            RowLayout {
                                width: parent.width

                                Row {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: streamCard.streamMuted ? "󰝟" : ""
                                        font.family: Icons.effectiveFont("󰝟")
                                        font.pixelSize: 14
                                        color: streamCard.streamMuted ? Theme.red : Theme.foreground
                                        anchors.verticalCenter: parent.verticalCenter

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.service.toggleStreamMute(streamCard.streamNode)
                                        }
                                    }

                                    Text {
                                        text: streamCard.streamName
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.foreground
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    text: streamCard.streamMuted ? "MUTED" : (Math.round(streamSlider.liveValue) + "%")
                                    font.family: Fonts.monoFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.foreground
                                }
                            }

                            AudioSlider {
                                id: streamSlider
                                width: parent.width
                                from: 0
                                to: 150
                                value: streamCard.streamVolume
                                muted: streamCard.streamMuted
                                onMoved: function(v) {
                                    root.service.setStreamVolume(streamCard.streamNode, v)
                                }
                                onRightClicked: {
                                    root.service.toggleStreamMute(streamCard.streamNode)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
