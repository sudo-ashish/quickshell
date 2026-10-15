import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"
import "../services"
import "../widgets"
import "../components"

PanelWindow {
    id: root

    required property WorkspacesService workspacesService
    required property AudioService audioService
    required property BrightnessService brightnessService
    required property BatteryService batteryService
    required property NetworkService networkService
    required property BluetoothService bluetoothService
    required property PowerService powerService

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Auto

    // Main Bar Frosted Surface
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
    }

    // Bottom hairline separator with center cutout for liquid power menu integration
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1

        // Center cutout tracking power menu droplet width
        Item {
            id: centerCutout
            anchors.centerIn: parent
            width: (root.powerService && root.powerService.powerMenuOpen) ? 424 : 0
            height: 1
            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        // Left hairline segment: extends from screen left to droplet neck
        Rectangle {
            anchors.left: parent.left
            anchors.right: centerCutout.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Theme.selection
        }

        // Right hairline segment: extends from droplet neck to screen right
        Rectangle {
            anchors.left: centerCutout.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Theme.selection
        }
    }

    // Main Bar Content Container
    Item {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        // Left Section: Workspaces & One UI 7 Now Bar
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            WorkspacesWidget {
                service: root.workspacesService
            }

            NowBarPill {
                audioService: root.audioService
            }
        }

        // Center Section: Date & Time
        Item {
            anchors.centerIn: parent
            width: clockWidget.width
            height: parent.height

            ClockWidget {
                id: clockWidget
                anchors.centerIn: parent
                powerService: root.powerService
                opacity: (root.powerService && root.powerService.powerMenuOpen) ? 0.0 : 1.0
                scale: (root.powerService && root.powerService.powerMenuOpen) ? 0.8 : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
                Behavior on scale {
                    NumberAnimation { duration: 150 }
                }
            }
        }

        // Right Section: Hardware & Status Widgets
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            BluetoothWidget {
                id: bluetoothWidget
                service: root.bluetoothService
            }

            NetworkWidget {
                id: networkWidget
                service: root.networkService
            }

            AudioWidget {
                id: audioWidget
                service: root.audioService
            }

            MonitorWidget {
                id: monitorWidget
                service: root.brightnessService
            }

            BatteryWidget {
                id: batteryWidget
                batteryService: root.batteryService
                powerService: root.powerService
            }
        }
    }

    IpcHandler {
        target: "barpopups"
        function toggle(name: string): string {
            if (name === "clock") clockWidget.toggle()
            else if (name === "monitor") monitorWidget.toggle()
            else if (name === "battery") batteryWidget.toggle()
            else if (name === "network") networkWidget.toggle()
            else if (name === "audio") audioWidget.toggle()
            else if (name === "bluetooth") bluetoothWidget.toggle()
            return "ok"
        }
    }
}
