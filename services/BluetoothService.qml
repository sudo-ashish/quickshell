import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    signal deviceConnected(string name, string mac)
    signal deviceDisconnected(string name, string mac)
    signal bluetoothDisconnecting()
    signal requestToggleMenu()

    property bool menuOpen: false

    property var _prevConnectedMap: ({})
    property bool _hasInitialSnapshot: false

    property bool bluetoothEnabled: true
    property var devices: []
    property var connectedDevices: []
    property var pairedDevices: []
    property alias savedDevices: root.pairedDevices
    property var availableDevices: []
    property bool scanning: false

    readonly property string icon: Icons.bluetoothStatus(root.bluetoothEnabled, root.connectedDevices.length)

    // Dynamic Bluetooth status phrases
    property int phraseIndex: 3
    readonly property var activePhrases: [
        "Untangling wires",
        "Streaming vikings",
        "Pairing mysteries",
        "Herding headsets",
        "Taming radios",
        "Summoning speakers",
        "Wrangling codecs",
        "Polishing packets"
    ]

    // Status tracking for Connect / Pair actions
    property string connectingMac: ""
    property string pairingMac: ""
    property string actionErrorMac: ""
    property string actionErrorMessage: ""

    readonly property string heroSubtitle: {
        if (!bluetoothEnabled) return "TURNED OFF"
        if (connectingMac !== "") return "CONNECTING DEVICE..."
        if (pairingMac !== "") return "PAIRING DEVICE..."
        if (connectedDevices.length > 0) return "WRANGLING CODECS"
        return activePhrases[phraseIndex % activePhrases.length].toUpperCase()
    }

    property Timer phraseTimer: Timer {
        interval: 3200
        repeat: true
        running: root.bluetoothEnabled && root.connectedDevices.length === 0 && root.connectingMac === "" && root.pairingMac === ""
        onTriggered: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }

    property Timer actionErrorTimer: Timer {
        interval: 3500
        repeat: false
        onTriggered: {
            root.actionErrorMac = ""
            root.actionErrorMessage = ""
        }
    }

    property Timer actionTimeoutTimer: Timer {
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.connectingMac || root.pairingMac) {
                root.actionErrorMac = root.connectingMac || root.pairingMac
                root.actionErrorMessage = "Timed out"
                root.connectingMac = ""
                root.pairingMac = ""
                actionErrorTimer.restart()
                if (actionProc.running) actionProc.running = false
                root.refresh()
            }
        }
    }

    property Process actionProc: Process {
        id: actionProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            actionTimeoutTimer.stop()
            var isPair = (root.pairingMac !== "")
            var targetMac = root.connectingMac || root.pairingMac
            root.connectingMac = ""
            root.pairingMac = ""

            if (exitCode !== 0) {
                root.actionErrorMac = targetMac
                root.actionErrorMessage = isPair ? "Pairing failed" : "Failed to connect"
                actionErrorTimer.restart()
            } else {
                root.actionErrorMac = ""
                root.actionErrorMessage = ""
            }
            root.refresh()
        }
    }

    function togglePower() {
        var next = !root.bluetoothEnabled
        root.bluetoothEnabled = next
        root.connectingMac = ""
        root.pairingMac = ""
        root.actionErrorMac = ""
        root.actionErrorMessage = ""
        if (!next) {
            root.bluetoothDisconnecting()
            if (root._hasInitialSnapshot) {
                for (var dm in root._prevConnectedMap) {
                    root.deviceDisconnected(root._prevConnectedMap[dm], dm)
                }
            }
            root._prevConnectedMap = {}
            root.connectedDevices = []
            root.pairedDevices = []
            root.availableDevices = []
            root.devices = []
            root.scanning = false
        }
        Quickshell.execDetached(["qdeck-bluetooth", "power", next ? "on" : "off"])
        refreshTimer.restart()
    }

    function connectDevice(mac, autoTrust) {
        if (!mac || !root.bluetoothEnabled || actionProc.running) return
        root.actionErrorMac = ""
        root.actionErrorMessage = ""
        root.connectingMac = mac
        root.pairingMac = ""
        actionTimeoutTimer.restart()
        actionProc.command = ["qdeck-bluetooth", "connect", mac]
        actionProc.running = true
    }

    function pairDevice(mac) {
        if (!mac || !root.bluetoothEnabled || actionProc.running) return
        root.actionErrorMac = ""
        root.actionErrorMessage = ""
        root.pairingMac = mac
        root.connectingMac = ""
        actionTimeoutTimer.restart()
        actionProc.command = ["qdeck-bluetooth", "pair", mac]
        actionProc.running = true
    }

    function disconnectDevice(mac) {
        if (!mac) return
        root.bluetoothDisconnecting()
        if (root.connectingMac === mac) root.connectingMac = ""
        if (root.pairingMac === mac) root.pairingMac = ""
        if (root.actionErrorMac === mac) {
            root.actionErrorMac = ""
            root.actionErrorMessage = ""
        }
        Quickshell.execDetached(["qdeck-bluetooth", "disconnect", mac])
        refreshTimer.restart()
    }

    function forgetDevice(mac) {
        if (!mac) return
        if (root.connectingMac === mac) root.connectingMac = ""
        if (root.pairingMac === mac) root.pairingMac = ""
        if (root.actionErrorMac === mac) {
            root.actionErrorMac = ""
            root.actionErrorMessage = ""
        }
        Quickshell.execDetached(["qdeck-bluetooth", "forget", mac])
        refreshTimer.restart()
    }

    function scan(timeoutSec) {
        if (!root.bluetoothEnabled) return
        root.scanning = true
        var t = timeoutSec ? String(timeoutSec) : "5"
        Quickshell.execDetached(["qdeck-bluetooth", "scan", t])
        scanTimer.restart()
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
        if (root.bluetoothEnabled && !devicesProc.running) devicesProc.running = true
    }

    property Timer scanTimer: Timer {
        id: scanTimer
        interval: 5500
        repeat: false
        onTriggered: {
            root.scanning = false
            root.refresh()
        }
    }

    property Timer refreshTimer: Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    // Auto-refresh fallback timer every 4 seconds
    property Timer autoRefreshTimer: Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    // Periodic auto-scan when Bluetooth menu is open and Bluetooth is on
    property Timer autoScanTimer: Timer {
        interval: 12000
        repeat: true
        running: root.bluetoothEnabled && root.menuOpen
        onTriggered: {
            if (root.bluetoothEnabled && !root.scanning) {
                root.scan()
            }
        }
    }

    // Real-time event listener via BlueZ D-Bus signals
    property Process bluezMonitorProc: Process {
        id: bluezMonitorProc
        command: ["gdbus", "monitor", "--system", "--dest", "org.bluez"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.indexOf("'Connected':") !== -1 ||
                    line.indexOf("PropertiesChanged") !== -1 ||
                    line.indexOf("InterfacesAdded") !== -1 ||
                    line.indexOf("InterfacesRemoved") !== -1) {
                    refreshTimer.restart()
                }
            }
        }
    }

    property Process statusProc: Process {
        id: statusProc
        command: ["qdeck-bluetooth", "status"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = text.trim().toLowerCase().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim()
                    if (l.indexOf("powered:") === 0) {
                        var isPowered = (l.indexOf("yes") !== -1)
                        root.bluetoothEnabled = isPowered
                        if (!isPowered) {
                            root.connectedDevices = []
                            root.pairedDevices = []
                            root.availableDevices = []
                            root.devices = []
                            root.scanning = false
                        }
                    }
                    if (l.indexOf("discovering:") === 0) {
                        var isDisc = (l.indexOf("yes") !== -1)
                        if (!scanTimer.running) {
                            root.scanning = isDisc
                        }
                    }
                }
            }
        }
    }

    property Process devicesProc: Process {
        id: devicesProc
        command: ["qdeck-bluetooth", "list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (!root.bluetoothEnabled) {
                    root.connectedDevices = []
                    root.pairedDevices = []
                    root.availableDevices = []
                    root.devices = []
                    return
                }

                var out = text.trim()
                if (!out) {
                    root.connectedDevices = []
                    root.pairedDevices = []
                    root.availableDevices = []
                    root.devices = []
                    return
                }

                var connLines = []
                var pairLines = []
                var allLines = []

                var currentSection = ""
                var lines = out.split("\n")
                for (var k = 0; k < lines.length; k++) {
                    var line = lines[k].trim()
                    if (!line) continue
                    if (line === "===CONNECTED===") {
                        currentSection = "connected"
                        continue
                    } else if (line === "===PAIRED===") {
                        currentSection = "paired"
                        continue
                    } else if (line === "===ALL===") {
                        currentSection = "all"
                        continue
                    }

                    if (currentSection === "connected") connLines.push(line)
                    else if (currentSection === "paired") pairLines.push(line)
                    else if (currentSection === "all") allLines.push(line)
                }

                // 1. Process Connected Devices
                var connMap = {}
                var connList = []
                for (var i = 0; i < connLines.length; i++) {
                    var cl = connLines[i].trim()
                    var cparts = cl.split(" ")
                    if (cparts.length >= 3 && cparts[0] === "Device") {
                        var cmac = cparts[1]
                        var rawName = cparts.slice(2).join(" ")
                        var batt = ""
                        var battMatch = rawName.match(/\[battery:([0-9]+)\]/)
                        if (battMatch) {
                            batt = battMatch[1] + "%"
                            rawName = rawName.replace(/\s*\[battery:[0-9]+\]/, "").trim()
                        }
                        var cDev = {
                            mac: cmac,
                            name: rawName || cmac,
                            battery: batt,
                            connected: true,
                            paired: true
                        }
                        connMap[cmac] = cDev
                        connList.push(cDev)
                    }
                }

                // Connection and disconnection notification signals
                if (root._hasInitialSnapshot) {
                    for (var cm in connMap) {
                        if (!root._prevConnectedMap[cm]) {
                            root.deviceConnected(connMap[cm].name, cm)
                        }
                    }
                    for (var pm in root._prevConnectedMap) {
                        if (!connMap[pm]) {
                            root.deviceDisconnected(root._prevConnectedMap[pm], pm)
                        }
                    }
                }
                var nextPrevMap = {}
                for (var curM in connMap) {
                    nextPrevMap[curM] = connMap[curM].name
                }
                root._prevConnectedMap = nextPrevMap
                root._hasInitialSnapshot = true

                root.connectedDevices = connList

                // Clear connecting state if device is now connected
                if (root.connectingMac) {
                    for (var ci = 0; ci < connList.length; ci++) {
                        if (connList[ci].mac === root.connectingMac) {
                            root.connectingMac = ""
                            root.actionErrorMac = ""
                            root.actionErrorMessage = ""
                            break
                        }
                    }
                }

                // 2. Process Paired (Non-connected) Devices
                var pairMap = {}
                var pairList = []
                for (var j = 0; j < pairLines.length; j++) {
                    var pl = pairLines[j].trim()
                    var pparts = pl.split(" ")
                    if (pparts.length >= 3 && pparts[0] === "Device") {
                        var pmac = pparts[1]
                        var pname = pparts.slice(2).join(" ")
                        pairMap[pmac] = true
                        if (!connMap[pmac]) {
                            pairList.push({
                                mac: pmac,
                                name: pname || pmac,
                                battery: "",
                                connected: false,
                                paired: true
                            })
                        }
                    }
                }
                root.pairedDevices = pairList

                // 3. Process Available (Discovered, un-paired, un-connected) Devices
                var availMap = {}
                var availList = []
                for (var ai = 0; ai < allLines.length; ai++) {
                    var al = allLines[ai].trim()
                    var aparts = al.split(" ")
                    if (aparts.length >= 3 && aparts[0] === "Device") {
                        var amac = aparts[1]
                        var aname = aparts.slice(2).join(" ")
                        if (!connMap[amac] && !pairMap[amac] && !availMap[amac]) {
                            if (aname && aname !== amac && !/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(aname)) {
                                availMap[amac] = true
                                availList.push({
                                    mac: amac,
                                    name: aname,
                                    battery: "",
                                    connected: false,
                                    paired: false
                                })
                            }
                        }
                    }
                }
                root.availableDevices = availList

                var fullList = []
                for (var c = 0; c < connList.length; c++) fullList.push(connList[c])
                for (var p = 0; p < pairList.length; p++) fullList.push(pairList[p])
                for (var a = 0; a < availList.length; a++) fullList.push(availList[a])
                root.devices = fullList
            }
        }
    }

    // IPC Interface
    property IpcHandler ipcHandler: IpcHandler {
        target: "bluetooth"
        function toggle(): string {
            root.requestToggleMenu()
            return "ok"
        }
        function open(): string {
            root.requestToggleMenu()
            return "ok"
        }
    }

    Component.onCompleted: {
        root.refresh()
    }
}
