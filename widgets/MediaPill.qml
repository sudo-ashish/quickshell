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
    implicitWidth: hasMedia ? Math.min(220, Math.max(120, titleMeasure.implicitWidth + 76)) : 0
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
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
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

    // Outer Capsule Pill Container (Black pill)
    Rectangle {
        id: pillBg
        anchors.fill: parent
        radius: Appearance.mediaPillRadius

        color: pillMouse.containsMouse ? Theme.lighter_background : Theme.dark_background
        border.color: "transparent"
        border.width: 0

        opacity: mediaPopup.open ? 0.0 : 1.0
        scale: mediaPopup.open ? 0.45 : 1.0
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Behavior on scale {
            NumberAnimation {
                duration: mediaPopup.open ? 160 : 280
                easing.type: mediaPopup.open ? Easing.InCubic : Easing.OutCubic
            }
        }

        Behavior on color { ColorAnimation { duration: 150 } }

        // 1. Mini Rounded Album Thumbnail on Left Side
        Item {
            id: miniArtBox
            width: 18
            height: 18
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
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

        // 2. Album / Media Name in Middle
        Text {
            id: titleText
            anchors.left: miniArtBox.right
            anchors.leftMargin: 7
            anchors.right: eqRow.left
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

        // 3. 3-bar Equalizer Icon on Right
        // Animated while playing, held flat (3px) when paused
        Row {
            id: eqRow
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2.2
            height: 14

            // Bar 1
            Rectangle {
                width: 2.2
                height: (root.controller && root.controller.isPlaying) ? 9 : 3
                radius: 1
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 11; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 4; duration: 280; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 9; duration: 200; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 3; duration: 260; easing.type: Easing.InOutQuad }
                }
            }

            // Bar 2
            Rectangle {
                width: 2.2
                height: (root.controller && root.controller.isPlaying) ? 12 : 3
                radius: 1
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 4; duration: 220; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 13; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 6; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 11; duration: 210; easing.type: Easing.InOutQuad }
                }
            }

            // Bar 3
            Rectangle {
                width: 2.2
                height: (root.controller && root.controller.isPlaying) ? 8 : 3
                radius: 1
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 10; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 3; duration: 220; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 8; duration: 250; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 5; duration: 230; easing.type: Easing.InOutQuad }
                }
            }
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

    // IPC Interface for toggling media popup
    IpcHandler {
        target: "mediapill"
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

    // Expanded One UI 7 Frosted Glass Media Card
    MediaPopup {
        id: mediaPopup
        anchorItem: root
        controller: root.controller
        audioService: root.audioService
    }
}
