import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../services"

PanelWindow {
    id: root

    property PowerService powerService: null
    property bool isOpen: false
    property real animProgress: 0.0
    property int selectedIndex: 0

    // Keep window mapped while closing animation completes
    visible: root.isOpen || closeAnim.running

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // Bind dynamically to the currently focused Hyprland monitor
    screen: {
        if (!Quickshell.screens || Quickshell.screens.length === 0) return null
        var foc = Hyprland.focusedMonitor
        if (foc && foc.name) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === foc.name) {
                    return Quickshell.screens[i]
                }
            }
        }
        return Quickshell.screens[0]
    }

    // LayerShell configuration (quickshell-powermenu inherits Hyprland blur + ignorealpha 0.57)
    WlrLayershell.namespace: "quickshell-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Spring expansion & retraction physics
    NumberAnimation {
        id: openAnim
        target: root
        property: "animProgress"
        from: root.animProgress
        to: 1.0
        duration: 360
        easing.type: Easing.OutBack
        easing.overshoot: 1.18
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "animProgress"
        from: root.animProgress
        to: 0.0
        duration: 220
        easing.type: Easing.InCubic
        onFinished: {
            if (!root.isOpen) {
                root.selectedIndex = 0
                if (root.powerService) {
                    root.powerService.powerMenuOpen = false
                }
            }
        }
    }

    function open() {
        closeAnim.stop()
        root.isOpen = true
        root.selectedIndex = 0
        if (root.powerService) {
            root.powerService.powerMenuOpen = true
        }
        openAnim.restart()
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
        })
    }

    function close() {
        openAnim.stop()
        root.isOpen = false
        if (root.powerService) {
            root.powerService.powerMenuOpen = false
        }
        closeAnim.restart()
    }

    function toggle() {
        if (root.isOpen) {
            root.close()
        } else {
            root.open()
        }
    }

    onIsOpenChanged: {
        if (root.isOpen) {
            if (root.powerService) {
                root.powerService.powerMenuOpen = true
            }
            Qt.callLater(function() {
                keyCatcher.forceActiveFocus()
            })
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IPC Handler for CLI & external integration
    // ─────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "powermenu"

        function open(): string {
            root.open()
            return "ok"
        }

        function close(): string {
            root.close()
            return "ok"
        }

        function toggle(): string {
            root.toggle()
            return root.isOpen ? "open" : "closed"
        }

        function next(): string {
            root.selectedIndex = (root.selectedIndex + 1) % 4
            return String(root.selectedIndex)
        }

        function prev(): string {
            root.selectedIndex = (root.selectedIndex - 1 + 4) % 4
            return String(root.selectedIndex)
        }

        function select(idx: string): string {
            var n = parseInt(idx, 10)
            if (!isNaN(n) && n >= 0 && n < 4) {
                root.selectedIndex = n
            }
            return String(root.selectedIndex)
        }

        function getState(): string {
            return JSON.stringify({
                isOpen: root.isOpen,
                animProgress: root.animProgress,
                selectedIndex: root.selectedIndex,
                selectedAction: root.actions[root.selectedIndex].id,
                actions: ["lock", "logout", "restart", "shutdown"],
                baseOpacity: Theme.baseOpacity,
                blurEnabled: Theme.blurEnabled
            })
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Transparent Backdrop Click Catcher (NO dark scrim to avoid color tint mismatch)
    // ─────────────────────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Hyprland focus grab for compositor-level dismissal on outside clicks
    HyprlandFocusGrab {
        active: root.isOpen
        windows: [root]
        onCleared: root.close()
    }

    // Action definitions
    readonly property var actions: [
        {
            id: "lock",
            icon: "󰌾",
            isUrgent: false,
            exec: function() {
                root.close()
                Quickshell.execDetached(["sh", "-c", "loginctl lock-session || hyprlock || swaylock"])
            }
        },
        {
            id: "logout",
            icon: "󰍃",
            isUrgent: false,
            exec: function() {
                root.close()
                Quickshell.execDetached(["sh", "-c", "hyprctl dispatch exit || loginctl terminate-user \"$USER\""])
            }
        },
        {
            id: "restart",
            icon: "󰑓",
            isUrgent: true,
            exec: function() {
                root.close()
                Quickshell.execDetached(["systemctl", "reboot"])
            }
        },
        {
            id: "shutdown",
            icon: "󰐥",
            isUrgent: true,
            exec: function() {
                root.close()
                Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    ]

    // ─────────────────────────────────────────────────────────────────────────
    // Keyboard Navigation Controller
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.isOpen

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.selectedIndex = (root.selectedIndex - 1 + 4) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.selectedIndex = (root.selectedIndex + 1) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.selectedIndex = (root.selectedIndex - 1 + 4) % 4
                } else {
                    root.selectedIndex = (root.selectedIndex + 1) % 4
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Backtab) {
                root.selectedIndex = (root.selectedIndex - 1 + 4) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_1) {
                root.selectedIndex = 0
                root.actions[0].exec()
                event.accepted = true
            } else if (event.key === Qt.Key_2) {
                root.selectedIndex = 1
                root.actions[1].exec()
                event.accepted = true
            } else if (event.key === Qt.Key_3) {
                root.selectedIndex = 2
                root.actions[2].exec()
                event.accepted = true
            } else if (event.key === Qt.Key_4) {
                root.selectedIndex = 3
                root.actions[3].exec()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.selectedIndex >= 0 && root.selectedIndex < root.actions.length) {
                    root.actions[root.selectedIndex].exec()
                }
                event.accepted = true
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Liquid Droplet Container (Emerging directly out of the Top Bar at y=0)
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: dropletContainer

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // Dynamic geometry starting flush with the bar (Hbar) and expanding down to Hbar + 95
        readonly property real hBar: Theme.barHeight
        readonly property real bodyW: 140 + 240 * Math.max(0, root.animProgress)
        readonly property real rn: Math.max(0.001, 22 * root.animProgress)
        readonly property real rb: Math.max(0.001, 24 * root.animProgress)

        width: bodyW + 2 * rn
        height: hBar + 95 * Math.max(0, root.animProgress)
        clip: true

        // ─────────────────────────────────────────────────────────────────────
        // Liquid Seam Shape (Starts from top of screen y=0, welded to bar bottom at y=hBar)
        // ─────────────────────────────────────────────────────────────────────
        Shape {
            id: dropletShape
            anchors.fill: parent

            readonly property real w: dropletContainer.width
            readonly property real h: dropletContainer.height
            readonly property real hBar: dropletContainer.hBar
            readonly property real rn: dropletContainer.rn
            readonly property real rb: dropletContainer.rb

            // 1. Primary Frosted Liquid Surface (Exact same color & opacity as Bar.qml)
            // 1. Primary Frosted Liquid Surface (Starts at y=hBar, zero overlap with Bar.qml)
            ShapePath {
                id: dropletFillPath
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: Theme.withAlpha(Theme.background, Theme.baseOpacity)

                startX: 0
                startY: dropletShape.hBar

                // Bar bottom neck weld line across top
                PathLine {
                    x: dropletShape.w
                    y: dropletShape.hBar
                }

                // Top-Right Inverted (Concave) Fillet neck welding to bar
                PathArc {
                    x: dropletShape.w - dropletShape.rn
                    y: dropletShape.hBar + dropletShape.rn
                    radiusX: dropletShape.rn
                    radiusY: dropletShape.rn
                    direction: PathArc.Counterclockwise
                }

                // Right vertical droplet body edge
                PathLine {
                    x: dropletShape.w - dropletShape.rn
                    y: Math.max(dropletShape.hBar + dropletShape.rn, dropletShape.h - dropletShape.rb)
                }

                // Bottom-Right Convex Corner
                PathArc {
                    x: dropletShape.w - dropletShape.rn - dropletShape.rb
                    y: dropletShape.h
                    radiusX: dropletShape.rb
                    radiusY: dropletShape.rb
                    direction: PathArc.Clockwise
                }

                // Bottom horizontal edge
                PathLine {
                    x: dropletShape.rn + dropletShape.rb
                    y: dropletShape.h
                }

                // Bottom-Left Convex Corner
                PathArc {
                    x: dropletShape.rn
                    y: Math.max(dropletShape.hBar + dropletShape.rn, dropletShape.h - dropletShape.rb)
                    radiusX: dropletShape.rb
                    radiusY: dropletShape.rb
                    direction: PathArc.Clockwise
                }

                // Left vertical droplet body edge
                PathLine {
                    x: dropletShape.rn
                    y: dropletShape.hBar + dropletShape.rn
                }

                // Top-Left Inverted (Concave) Fillet neck welding to bar
                PathArc {
                    x: 0
                    y: dropletShape.hBar
                    radiusX: dropletShape.rn
                    radiusY: dropletShape.rn
                    direction: PathArc.Counterclockwise
                }
            }

            // 2. Continuous Bottom Hairline Separator (Seamlessly bridges with Bar.qml's hairline)
            ShapePath {
                id: dropletOutlinePath
                strokeColor: Theme.withAlpha(Theme.selection, Math.min(1.0, root.animProgress * 1.5))
                strokeWidth: 1
                fillColor: "transparent"

                startX: 0
                startY: dropletShape.hBar

                // Top-Left Inverted (Concave) Fillet
                PathArc {
                    x: dropletShape.rn
                    y: dropletShape.hBar + dropletShape.rn
                    radiusX: dropletShape.rn
                    radiusY: dropletShape.rn
                    direction: PathArc.Clockwise
                }

                // Left vertical edge
                PathLine {
                    x: dropletShape.rn
                    y: Math.max(dropletShape.hBar + dropletShape.rn, dropletShape.h - dropletShape.rb)
                }

                // Bottom-Left Convex Corner
                PathArc {
                    x: dropletShape.rn + dropletShape.rb
                    y: dropletShape.h
                    radiusX: dropletShape.rb
                    radiusY: dropletShape.rb
                    direction: PathArc.Counterclockwise
                }

                // Bottom horizontal edge
                PathLine {
                    x: dropletShape.w - dropletShape.rn - dropletShape.rb
                    y: dropletShape.h
                }

                // Bottom-Right Convex Corner
                PathArc {
                    x: dropletShape.w - dropletShape.rn
                    y: Math.max(dropletShape.hBar + dropletShape.rn, dropletShape.h - dropletShape.rb)
                    radiusX: dropletShape.rb
                    radiusY: dropletShape.rb
                    direction: PathArc.Counterclockwise
                }

                // Right vertical edge
                PathLine {
                    x: dropletShape.w - dropletShape.rn
                    y: dropletShape.hBar + dropletShape.rn
                }

                // Top-Right Inverted (Concave) Fillet
                PathArc {
                    x: dropletShape.w
                    y: dropletShape.hBar
                    radiusX: dropletShape.rn
                    radiusY: dropletShape.rn
                    direction: PathArc.Clockwise
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Bar-Zone Center Header (Inside the 0..Theme.barHeight region)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: barZoneHeader
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: dropletContainer.bodyW
            height: dropletContainer.hBar

            Row {
                anchors.centerIn: parent
                spacing: 6
                opacity: Math.max(0, Math.min(1.0, (root.animProgress - 0.15) / 0.85))

                Text {
                    text: "󰐥"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Session"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // 4 Horizontal Session Actions (Inside the expanded body below the bar)
        // ─────────────────────────────────────────────────────────────────────
        RowLayout {
            id: buttonRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: dropletContainer.hBar + 12
            spacing: 14

            Repeater {
                model: root.actions

                Item {
                    id: actionBtn
                    required property var modelData
                    required property int index

                    readonly property bool isActive: root.selectedIndex === index

                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 68

                    // Staggered pop-in animation tied to droplet expansion
                    opacity: Math.max(0, Math.min(1.0, (root.animProgress - index * 0.08) / 0.7))
                    scale: (actionBtn.isActive ? 1.07 : 1.0) * Math.max(0.7, Math.min(1.0, 0.7 + 0.3 * root.animProgress))

                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.18
                        }
                    }

                    // Button surface with squircle morph (radius 22 -> 16) and shell theme matching
                    Rectangle {
                        id: btnBg
                        anchors.fill: parent
                        radius: actionBtn.isActive ? 16 : 28

                        Behavior on radius {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutBack
                            }
                        }

                        color: {
                            if (actionBtn.isActive) {
                                return actionBtn.modelData.isUrgent ? Theme.urgent : Theme.accent
                            }
                            if (mouseArea.containsMouse) {
                                return Theme.lighter_background
                            }
                            return Theme.withAlpha(Theme.background, Theme.baseOpacity)
                        }

                        border.color: actionBtn.isActive ? "transparent" : Theme.selection
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 160 }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: {
                                root.selectedIndex = actionBtn.index
                            }
                            onClicked: {
                                actionBtn.modelData.exec()
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: actionBtn.modelData.icon
                                font.family: Theme.fontFamily
                                font.pixelSize: 28
                                color: actionBtn.isActive 
                                    ? Theme.darker_background 
                                    : (actionBtn.modelData.isUrgent ? Theme.urgent : Theme.foreground)

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: actionBtn.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: actionBtn.isActive ? Font.Bold : Font.DemiBold
                                color: actionBtn.isActive ? Theme.darker_background : Theme.foreground

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
