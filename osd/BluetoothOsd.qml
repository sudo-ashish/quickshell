import QtQuick
import Quickshell
import Quickshell.Bluetooth

Item {
    id: root

    signal deviceConnected(string name, string mac)
    signal deviceDisconnected(string name, string mac)

    property bool ready: false

    // Startup debounce guard to prevent flashing notifications for devices
    // that are already connected when the shell boots
    Timer {
        id: startupGuardTimer
        interval: 2000
        running: true
        repeat: false
        onTriggered: root.ready = true
    }

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    // Pure event-driven watcher over Quickshell's native C++ Bluetooth object model
    Instantiator {
        model: root.adapter ? root.adapter.devices : null

        Item {
            id: watcher
            required property BluetoothDevice modelData

            property bool wasConnected: false

            Component.onCompleted: {
                wasConnected = modelData.connected
            }

            // Debounce disconnect notification to suppress transient handshake disconnect blips
            // when Bluetooth devices power on and negotiate profiles with BlueZ
            Timer {
                id: disconnectDebounceTimer
                interval: 1200
                repeat: false
                onTriggered: {
                    if (!modelData.connected && watcher.wasConnected) {
                        watcher.wasConnected = false
                        if (root.ready) {
                            var devName = modelData.name || modelData.deviceName || "Bluetooth Device"
                            var devMac = modelData.address || ""
                            root.deviceDisconnected(devName, devMac)
                        }
                    }
                }
            }

            Component.onDestruction: {
                disconnectDebounceTimer.stop()
                if (watcher.wasConnected && root.ready) {
                    var devName = modelData ? (modelData.name || modelData.deviceName || "Bluetooth Device") : "Bluetooth Device"
                    var devMac = modelData ? (modelData.address || "") : ""
                    root.deviceDisconnected(devName, devMac)
                }
            }

            Connections {
                target: modelData
                ignoreUnknownSignals: true

                function onConnectedChanged() {
                    var isNowConnected = modelData.connected
                    var devName = modelData.name || modelData.deviceName || "Bluetooth Device"
                    var devMac = modelData.address || ""

                    if (isNowConnected) {
                        // Cancel any pending disconnect debounce immediately
                        disconnectDebounceTimer.stop()
                        if (!watcher.wasConnected) {
                            watcher.wasConnected = true
                            if (root.ready) {
                                root.deviceConnected(devName, devMac)
                            }
                        }
                    } else {
                        // Device dropped connection: wait 1200ms before announcing disconnect.
                        // If it reconnects during RFCOMM/A2DP profile setup, disconnect is cancelled.
                        if (watcher.wasConnected) {
                            disconnectDebounceTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
