import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property int capacity: 100
    property string status: "Full"
    property string statusDisplay: "FULLY CHARGED"
    property bool isCharging: false
    property string batterySize: "40Wh"
    property string cycleCount: "177"
    property string timeLabel: "Time to full"
    property string timeToFull: "-"
    property string chargingRate: "-"

    readonly property string icon: Icons.battery(root.capacity, root.isCharging)

    function refresh() {
        if (!getBatteryProc.running) getBatteryProc.running = true
    }

    property Process getBatteryProc: Process {
        id: getBatteryProc
        command: ["qdeck-battery-info"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim())
                    if (data) {
                        if (typeof data.capacity === "number") root.capacity = data.capacity
                        if (data.status) root.status = data.status
                        if (data.statusDisplay) root.statusDisplay = data.statusDisplay
                        if (typeof data.isCharging === "boolean") root.isCharging = data.isCharging
                        if (data.batterySize) root.batterySize = data.batterySize
                        if (data.cycleCount) root.cycleCount = String(data.cycleCount)
                        if (data.timeLabel) root.timeLabel = data.timeLabel
                        if (data.timeToFull) root.timeToFull = data.timeToFull
                        if (data.chargingRate) root.chargingRate = data.chargingRate
                    }
                } catch (e) {
                    // ignore json parsing errors
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
