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

    // Bottom hairline separator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.selection
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
