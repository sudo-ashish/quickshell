import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property bool wifiEnabled: true
    property string currentSsid: ""
    property int signalStrength: 75
    property string localIp: ""
    property string interfaceName: ""
    property string gateway: ""
    property string connectionType: "wifi"
    property real rxBytes: 0
    property real txBytes: 0
    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real prevSampleTime: 0
    property real downloadRate: 0
    property real uploadRate: 0
    property real pingMs: -1
    property int packetLoss: 0
    property string dnsProvider: "DHCP"
    property string connectionPhrase: "ROUTING CRUMBS"

    property var knownNetworks: []
    property var otherNetworks: []
    property var networks: []
    property bool scanning: false

    property var qrMatrix: []
    property int qrSize: 0
    property bool qrLoading: false
    property string qrError: ""

    readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google"]

    readonly property string icon: Icons.network(root.connectionType, root.wifiEnabled, root.currentSsid, root.signalStrength)

    function wifiIconFor(signal) {
        return Icons.wifiSignal(signal)
    }

    function formatBytes(bytes) {
        var n = Number(bytes)
        if (!isFinite(n) || n <= 0) return "--"
        if (n < 1024) return Math.round(n) + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatRate(bytesPerSec) {
        var n = Number(bytesPerSec)
        if (!isFinite(n) || n <= 0) return "0 B/s"
        return formatBytes(n) + "/s"
    }

    function formatPing(ms) {
        var n = parseFloat(ms)
        if (!isFinite(n) || n < 0) return "--"
        return Math.round(n) + " ms"
    }

    function toggleWifi() {
        var nextState = !root.wifiEnabled
        root.wifiEnabled = nextState
        Quickshell.execDetached(["nmcli", "radio", "wifi", nextState ? "on" : "off"])
        refreshTimer.restart()
    }

    function setDns(provider) {
        if (!provider) return
        root.dnsProvider = provider
        Quickshell.execDetached(["qdeck-dns", provider])
        refreshTimer.restart()
    }


    function generateQr() {
        if (qrProc.running) return
        root.qrLoading = true
        root.qrError = ""
        qrProc.running = true
    }

    // Status tracking for connecting to Wi-Fi
    property string connectingSsid: ""
    property string connectionErrorSsid: ""
    property string connectionErrorMessage: ""

    property Timer connectionErrorTimer: Timer {
        interval: 4000
        repeat: false
        onTriggered: {
            root.connectionErrorSsid = ""
            root.connectionErrorMessage = ""
        }
    }

    property Timer connectTimeoutTimer: Timer {
        interval: 22000
        repeat: false
        onTriggered: {
            if (root.connectingSsid) {
                root.connectionErrorSsid = root.connectingSsid
                root.connectionErrorMessage = "Timed out"
                root.connectingSsid = ""
                connectionErrorTimer.restart()
                if (connectProc.running) connectProc.running = false
                root.refresh()
                root.scanWifi()
            }
        }
    }

    property Process connectProc: Process {
        id: connectProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var err = String(text || "").trim()
                if (err.length > 0) {
                    if (err.indexOf("Secrets were required") !== -1 || err.indexOf("No secret provided") !== -1) {
                        root.connectionErrorMessage = "Wrong password"
                    } else if (err.indexOf("Association took too long") !== -1 || err.indexOf("timed out") !== -1) {
                        root.connectionErrorMessage = "Timeout"
                    } else {
                        root.connectionErrorMessage = "Connection failed"
                    }
                }
            }
        }
        onExited: function(exitCode, exitStatus) {
            connectTimeoutTimer.stop()
            var targetSsid = root.connectingSsid
            root.connectingSsid = ""
            if (exitCode !== 0) {
                root.connectionErrorSsid = targetSsid
                if (!root.connectionErrorMessage) {
                    root.connectionErrorMessage = "Connection failed"
                }
                connectionErrorTimer.restart()
            } else {
                root.connectionErrorSsid = ""
                root.connectionErrorMessage = ""
            }
            root.refresh()
            root.scanWifi()
        }
    }

    function connectToNetwork(ssid, password) {
        if (!ssid || connectProc.running) return
        root.connectionErrorSsid = ""
        root.connectionErrorMessage = ""
        root.connectingSsid = ssid
        connectTimeoutTimer.restart()

        var args = ["nmcli", "dev", "wifi", "connect", ssid]
        if (password && password.length > 0) {
            args.push("password")
            args.push(password)
        }
        connectProc.command = args
        connectProc.running = true
    }

    function disconnectNetwork(ssid) {
        var target = ssid || root.currentSsid
        if (target && root.connectingSsid === target) {
            root.connectingSsid = ""
            if (connectProc.running) connectProc.running = false
        }
        if (target) {
            Quickshell.execDetached(["nmcli", "connection", "down", "id", target])
        }
        if (root.interfaceName) {
            Quickshell.execDetached(["nmcli", "device", "disconnect", root.interfaceName])
        }
        refreshTimer.restart()
        scanWifi()
    }

    function forgetNetwork(ssid) {
        if (!ssid) return
        if (root.connectingSsid === ssid) {
            root.connectingSsid = ""
            if (connectProc.running) connectProc.running = false
        }
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid])
        if (root.currentSsid === ssid) {
            root.currentSsid = ""
        }
        refreshTimer.restart()
        scanWifi()
    }

    function scanWifi() {
        if (!scanProc.running) {
            root.scanning = true
            scanProc.running = true
        }
    }

    function refresh() {
        if (!detailsProc.running) detailsProc.running = true
        if (!dnsProc.running) dnsProc.running = true
    }

    // 1. Live status & telemetry from qdeck-network-status --verbose
    property Process detailsProc: Process {
        id: detailsProc
        command: ["qdeck-network-status", "--verbose"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = String(text || "").split("\n")
                var kv = {}
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (!line) continue
                    var parts = line.split("\t")
                    if (parts.length >= 2) {
                        kv[parts[0].trim()] = parts[1].trim()
                    }
                }

                if (kv["type"]) root.connectionType = kv["type"]
                if (kv["iface"]) root.interfaceName = kv["iface"]
                if (kv["ip"]) root.localIp = kv["ip"]
                if (kv["gateway"]) root.gateway = kv["gateway"]
                if (kv["ssid"]) {
                    root.currentSsid = kv["ssid"]
                    if (root.connectingSsid === kv["ssid"]) {
                        root.connectingSsid = ""
                    }
                }

                if (kv["signal_dbm"]) {
                    var dbm = parseFloat(kv["signal_dbm"])
                    if (!isNaN(dbm)) {
                        root.signalStrength = Math.max(10, Math.min(100, Math.round(2 * (dbm + 100))))
                    }
                }

                var rx = parseFloat(kv["rx_bytes"] || "0")
                var tx = parseFloat(kv["tx_bytes"] || "0")
                root.rxBytes = rx
                root.txBytes = tx

                var now = Date.now() / 1000
                if (root.prevSampleTime > 0 && now > root.prevSampleTime) {
                    var dt = now - root.prevSampleTime
                    if (dt > 0.5) {
                        root.downloadRate = Math.max(0, (rx - root.prevRxBytes) / dt)
                        root.uploadRate = Math.max(0, (tx - root.prevTxBytes) / dt)
                    }
                }
                root.prevRxBytes = rx
                root.prevTxBytes = tx
                root.prevSampleTime = now

                var p = kv["internet_ping_ms"] || kv["router_ping_ms"]
                if (p) {
                    var pNum = parseFloat(p)
                    if (!isNaN(pNum) && pNum >= 0) {
                        root.pingMs = pNum
                        root.packetLoss = 0
                    } else {
                        root.pingMs = -1
                        root.packetLoss = 100
                    }
                } else {
                    root.pingMs = -1
                }
            }
        }
    }

    // 2. DNS Provider query
    property Process dnsProc: Process {
        id: dnsProc
        command: ["qdeck-dns"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var out = String(text || "").trim()
                if (out) {
                    root.dnsProvider = out
                }
            }
        }
    }

    // 3. QR Code generator
    property Process qrProc: Process {
        id: qrProc
        command: ["qdeck-network-qr", "--meta"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.qrLoading = false
                var lines = String(text || "").trim().split("\n")
                if (lines.length > 1) {
                    var matrix = []
                    for (var i = 1; i < lines.length; i++) {
                        var row = lines[i].trim()
                        if (row.length > 0) {
                            matrix.push(row)
                        }
                    }
                    root.qrMatrix = matrix
                    root.qrSize = matrix.length
                    root.qrError = ""
                } else {
                    root.qrError = "No active connection to share"
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var err = String(text || "").trim()
                if (err && root.qrMatrix.length === 0) {
                    root.qrError = err
                    root.qrLoading = false
                }
            }
        }
    }

    // 4. Wi-Fi Scan & Categorization into Known and Other Networks
    property Process scanProc: Process {
        id: scanProc
        command: ["bash", "-c", "echo '===SAVED==='; nmcli -t -f NAME,TYPE connection show 2>/dev/null; echo '===WIFI==='; nmcli -t -f active,ssid,signal,security dev wifi 2>/dev/null"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.scanning = false
                var output = String(text || "")
                var sections = output.split("===WIFI===")
                var savedSection = sections.length > 0 ? sections[0] : ""
                var wifiSection = sections.length > 1 ? sections[1] : ""

                // Extract saved SSIDs
                var knownSet = {}
                var savedLines = savedSection.split("\n")
                for (var i = 0; i < savedLines.length; i++) {
                    var sLine = savedLines[i].trim()
                    if (!sLine || sLine === "===SAVED===") continue
                    var sParts = sLine.split(":")
                    if (sParts.length >= 2 && sParts[1].indexOf("802-11-wireless") !== -1) {
                        knownSet[sParts[0]] = true
                    }
                }

                // Parse active & scanned networks
                var wifiLines = wifiSection.split("\n")
                var seen = {}
                var knownList = []
                var otherList = []
                var activeFound = false

                for (var j = 0; j < wifiLines.length; j++) {
                    var wLine = wifiLines[j].trim()
                    if (!wLine) continue
                    var wParts = wLine.split(":")
                    if (wParts.length >= 3) {
                        var isActive = (wParts[0] === "yes")
                        var ssid = wParts[1]
                        var signal = parseInt(wParts[2], 10) || 0
                        var security = wParts[3] || ""

                        if (!ssid || seen[ssid]) continue
                        seen[ssid] = true

                        var isSecured = (security.length > 0 && security.indexOf("--") === -1 && security.toLowerCase().indexOf("open") === -1)
                        var isKnown = isActive || (knownSet[ssid] === true)

                        var item = {
                            ssid: ssid,
                            signal: signal,
                            security: security,
                            isSecured: isSecured,
                            active: isActive
                        }

                        if (isActive) {
                            root.currentSsid = ssid
                            root.signalStrength = signal
                            activeFound = true
                            if (root.connectingSsid === ssid) {
                                root.connectingSsid = ""
                            }
                        }

                        if (isKnown) {
                            knownList.push(item)
                        } else {
                            otherList.push(item)
                        }
                    }
                }

                if (!activeFound && root.wifiEnabled && root.currentSsid === "") {
                    root.currentSsid = ""
                }

                // Sort: active first in knownList, then by signal descending
                knownList.sort(function(a, b) {
                    if (a.active !== b.active) return a.active ? -1 : 1
                    return b.signal - a.signal
                })

                otherList.sort(function(a, b) {
                    return b.signal - a.signal
                })

                root.knownNetworks = knownList
                root.otherNetworks = otherList
                root.networks = knownList.concat(otherList)
            }
        }
    }

    property Timer refreshTimer: Timer {
        id: refreshTimer
        interval: 600
        repeat: false
        onTriggered: root.refresh()
    }

    // Passive telemetry background polling (does not execute nmcli dev wifi scans)
    property Timer pollTimer: Timer {
        interval: 3500
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.refresh()
    }
}
