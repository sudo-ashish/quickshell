import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

Item {
    id: root

    property MediaController controller: MediaController { id: defaultCtrl }
    property AudioService audioService: null
    property alias popup: mediaPopup

    readonly property bool hasMedia: controller ? controller.hasMedia : false
    readonly property string trackTitle: root.controller ? (root.controller.title || root.controller.artist || "Music") : ""

    implicitHeight: Appearance.mediaPillHeight
    implicitWidth: hasMedia ? Math.min(220, Math.max(130, titleMeasure.implicitWidth + 82)) : 0
    height: implicitHeight
    width: implicitWidth

    visible: width > 0 || opacity > 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    opacity: hasMedia ? 1.0 : 0.0
    scale: hasMedia ? 1.0 : 0.85

    Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
    }

    // Hidden text measuring component for fluid pill expansion
    Text {
        id: titleMeasure
        text: root.trackTitle
        font.family: Fonts.uiFont
        font.pixelSize: Fonts.scale(11)
        font.weight: Fonts.weightBold
        visible: false
    }

    // Outer Capsule Pill Container (Black pill matching frame_pill.png)
    Rectangle {
        id: pillBg
        anchors.fill: parent
        radius: Appearance.mediaPillRadius

        color: pillMouse.containsMouse ? Theme.lighter_background : Theme.dark_background
        border.color: "transparent"
        border.width: 0

        // Disappear smoothly when popup opens, bounce back into view when closed
        opacity: mediaPopup.open ? 0.0 : 1.0
        scale: mediaPopup.open ? 0.45 : 1.0
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Behavior on scale {
            NumberAnimation {
                duration: mediaPopup.open ? 160 : 280
                easing.type: mediaPopup.open ? Easing.InBack : Easing.OutBack
                easing.overshoot: 1.45
            }
        }

        Behavior on color { ColorAnimation { duration: 150 } }

        // ── 1. Mini Rounded Album Art on Left Side ────────────────────────
        Item {
            id: miniArtBox
            width: 18
            height: 18
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: miniArtBg
                anchors.fill: parent
                radius: Appearance.radiusSmall
                color: Theme.dark_background

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.family: Icons.effectiveFont("󰝚")
                    font.pixelSize: Fonts.scale(10)
                    color: Theme.muted
                    visible: !miniArt.visible
                }

                Rectangle {
                    id: miniArtMask
                    anchors.fill: parent
                    radius: Appearance.radiusSmall
                    color: "black"
                    layer.enabled: true
                    visible: false
                }

                Image {
                    id: miniArt
                    anchors.fill: parent
                    source: root.controller ? root.controller.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    sourceSize.width: 36
                    sourceSize.height: 36
                    mipmap: true
                    smooth: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: miniArtMask
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.radiusSmall
                color: "transparent"
                border.color: "transparent"
                border.width: 0
                z: 2
            }
        }

        // ── 3. Audio Visualizer on Right Side (Matching Image 1) ──────────
        // 6 vertical white capsule bars, vertically centered along the midline
        Row {
            id: visualizerRow
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2.5
            height: 16

            // Bar 0: Short (Base 6px)
            Rectangle {
                width: 2.5
                height: root.controller && root.controller.isPlaying ? 6 : 6
                radius: width / 2
                color: root.controller && root.controller.isPlaying ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 150 } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 10; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 4; duration: 280; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 8; duration: 210; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 6; duration: 260; easing.type: Easing.InOutQuad }
                }
            }

            // Bar 1: Medium-High (Base 11px)
            Rectangle {
                width: 2.5
                height: root.controller && root.controller.isPlaying ? 11 : 11
                radius: width / 2
                color: root.controller && root.controller.isPlaying ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 150 } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 5; duration: 220; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 13; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 7; duration: 230; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 11; duration: 250; easing.type: Easing.InOutQuad }
                }
            }

            // Bar 2: Highest Peak (Base 14px)
            Rectangle {
                width: 2.5
                height: root.controller && root.controller.isPlaying ? 14 : 14
                radius: width / 2
                color: root.controller && root.controller.isPlaying ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 150 } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 7; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 15; duration: 230; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 9; duration: 270; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 14; duration: 220; easing.type: Easing.InOutQuad }
                }
            }

            // Bar 3: Medium-Short (Base 8px)
            Rectangle {
                width: 2.5
                height: root.controller && root.controller.isPlaying ? 8 : 8
                radius: width / 2
                color: root.controller && root.controller.isPlaying ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 150 } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 12; duration: 230; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 5; duration: 270; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 10; duration: 210; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 8; duration: 250; easing.type: Easing.InOutQuad }
                }
            }

            // Bar 4: High (Base 12px)
            Rectangle {
                width: 2.5
                height: root.controller && root.controller.isPlaying ? 12 : 12
                radius: width / 2
                color: root.controller && root.controller.isPlaying ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 150 } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 5; duration: 250; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 14; duration: 220; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 8; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 12; duration: 240; easing.type: Easing.InOutQuad }
                }
            }

            // Bar 5: High (Base 12px)
            Rectangle {
                width: 2.5
                height: root.controller && root.controller.isPlaying ? 12 : 12
                radius: width / 2
                color: root.controller && root.controller.isPlaying ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 150 } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 14; duration: 220; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 7; duration: 270; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 13; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 12; duration: 250; easing.type: Easing.InOutQuad }
                }
            }
        }

        // ── 2. Album / Media Name in Middle ───────────────────────────────
        Text {
            id: titleText
            anchors.left: miniArtBox.right
            anchors.leftMargin: 7
            anchors.right: visualizerRow.left
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter

            text: root.trackTitle
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.scale(11)
            font.weight: Fonts.weightBold
            color: Theme.foreground
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            enabled: !mediaPopup.open && mediaPopup.animProgress < 0.05
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaPopup.toggle()
        }
    }

    // IPC Interface for toggling media island popup
    IpcHandler {
        target: "media"
        function toggle(): string {
            mediaPopup.toggle()
            return "ok"
        }
        function open(): string {
            mediaPopup.open = true
            return "ok"
        }
        function close(): string {
            mediaPopup.open = false
            return "ok"
        }
    }

    // Expanded Aqua Dynamics / Dynamic Island Media Card
    MediaIslandPopup {
        id: mediaPopup
        anchorItem: root
        anchorWindow: root.QsWindow ? root.QsWindow.window : null
        controller: root.controller
        audioService: root.audioService
    }
}
