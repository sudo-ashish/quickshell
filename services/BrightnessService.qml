import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

QtObject {
    id: root

    signal brightnessAdjusted(int value)
    signal refreshRateChanged(int hz, string mode, string monitorName)

    property int brightness: 100
    property string brightnessName: "SUN BLAST"
    property int textSize: 12
    property string scale: "1"
    property string focusedMonitor: "eDP-1"
    property string selectedMonitorName: ""
    property string deviceName: "eDP-1"

    readonly property var activeMonitorObject: {
        var list = Hyprland.monitors ? Hyprland.monitors.values : []
        if (selectedMonitorName !== "") {
            for (var i = 0; i < list.length; i++) {
                if (list[i] && list[i].name === selectedMonitorName) return list[i]
            }
        }
        if (Hyprland.focusedMonitor) return Hyprland.focusedMonitor
        if (list.length > 0) return list[0]
        return null
    }

    readonly property string activeMonitorName: activeMonitorObject ? activeMonitorObject.name : (focusedMonitor || "eDP-1")

    function getSupportedRates(mon) {
        var modes = (mon && mon.lastIpcObject && mon.lastIpcObject.availableModes) ? mon.lastIpcObject.availableModes : []
        var rates = []
        for (var i = 0; i < modes.length; i++) {
            var m = String(modes[i]).match(/@([\d.]+)Hz/i)
            if (m && m[1]) {
                var r = Math.round(parseFloat(m[1]))
                if (!isNaN(r) && rates.indexOf(r) === -1) {
                    rates.push(r)
                }
            }
        }
        rates.sort(function(a, b) { return a - b })
        if (rates.length === 0) {
            var cur = Math.round(mon && mon.lastIpcObject ? mon.lastIpcObject.refreshRate : 60)
            if (cur > 60) rates = [60, cur]
            else rates = [60]
        }
        return rates
    }

    readonly property var activeSupportedRates: getSupportedRates(activeMonitorObject)
    readonly property int maxRefreshRate: activeSupportedRates.length > 0 ? activeSupportedRates[activeSupportedRates.length - 1] : 60
    readonly property int currentRefreshRate: (activeMonitorObject && activeMonitorObject.lastIpcObject && activeMonitorObject.lastIpcObject.refreshRate !== undefined) ? Math.round(activeMonitorObject.lastIpcObject.refreshRate) : 60
    readonly property int currentWidth: (activeMonitorObject && activeMonitorObject.width !== undefined) ? activeMonitorObject.width : (activeMonitorObject && activeMonitorObject.lastIpcObject && activeMonitorObject.lastIpcObject.width !== undefined ? activeMonitorObject.lastIpcObject.width : 1920)
    readonly property int currentHeight: (activeMonitorObject && activeMonitorObject.height !== undefined) ? activeMonitorObject.height : (activeMonitorObject && activeMonitorObject.lastIpcObject && activeMonitorObject.lastIpcObject.height !== undefined ? activeMonitorObject.lastIpcObject.height : 1080)
    readonly property string currentModeStr: currentWidth + "x" + currentHeight + " @ " + currentRefreshRate + "Hz"

    property string _lastReportedMode: ""
    property int _lastReportedHz: 0
    property bool _rateInitialized: false

    function checkModeChange() {
        if (!root._rateInitialized) return
        if (root.currentRefreshRate <= 0) return
        if (root.currentModeStr !== root._lastReportedMode) {
            root._lastReportedHz = root.currentRefreshRate
            root._lastReportedMode = root.currentModeStr
            root.refreshRateChanged(root.currentRefreshRate, root.currentWidth + "x" + root.currentHeight, root.activeMonitorName)
        }
    }

    onCurrentModeStrChanged: checkModeChange()

    property Timer initRateTimer: Timer {
        id: initRateTimer
        interval: 1800
        running: true
        onTriggered: {
            root._lastReportedHz = root.currentRefreshRate
            root._lastReportedMode = root.currentModeStr
            root._rateInitialized = true
        }
    }

    property Connections hyprConn: Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) {
            var evName = String(event.name || "")
            if (evName === "monitoradded" || evName === "monitoraddedv2" || evName === "monitorremoved" || evName === "focusedmon" || evName === "configreloaded") {
                Hyprland.refreshMonitors()
                root.refresh()
            }
        }
    }

    readonly property var displays: {
        var list = Hyprland.monitors ? Hyprland.monitors.values : []
        var res = []
        for (var i = 0; i < list.length; i++) {
            var m = list[i]
            if (!m) continue
            res.push({
                name: m.name,
                focused: (m.name === activeMonitorName),
                width: m.width,
                height: m.height,
                scale: m.scale,
                refreshRate: Math.round(m.lastIpcObject ? m.lastIpcObject.refreshRate : 60)
            })
        }
        return res
    }

    readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
    readonly property var scalePresets: ["1", "1.25", "1.6", "2", "3", "4"]

    readonly property string icon: Icons.brightnessLevel(root.brightness)

    function calculateBrightnessName(pct) {
        var p = Math.round(pct)
        if (p >= 95) return "SUN BLAST"
        if (p >= 80) return "SOLAR FLARE"
        if (p >= 65) return "GOLDEN HOUR"
        if (p >= 45) return "EVEN DAY"
        if (p >= 30) return "SOFT GLOW"
        if (p >= 20) return "LAMP LIGHT"
        if (p >= 10) return "CANDLELIT"
        return "NIGHT OWL"
    }

    property bool menuOpen: false
    property bool timerSuppressed: false
    readonly property bool suppressOsd: menuOpen || timerSuppressed

    function inhibitOsd(durationMs) {
        root.timerSuppressed = true
        osdInhibitTimer.interval = durationMs || 2000
        osdInhibitTimer.restart()
    }

    property Timer osdInhibitTimer: Timer {
        id: osdInhibitTimer
        interval: 2000
        repeat: false
        onTriggered: root.timerSuppressed = false
    }

    function selectDisplay(name) {
        if (!name) return
        root.selectedMonitorName = name
        root.focusedMonitor = name
        root.deviceName = name
    }

    function setBrightness(percent) {
        root.inhibitOsd(2000)
        var clamped = Math.max(1, Math.min(100, Math.round(percent)))
        root.brightness = clamped
        root.brightnessName = calculateBrightnessName(clamped)
        Quickshell.execDetached(["qdeck-brightness", "--no-osd", "--monitor", root.activeMonitorName, clamped + "%"])
    }

    function setTextSize(size) {
        var val = parseInt(size, 10)
        if (isNaN(val)) return
        root.textSize = val
        Theme.baseTextSize = val
        Quickshell.execDetached(["qdeck-display-text-size", String(val)])
        refreshDelayTimer.restart()
    }

    function setScale(scaleVal) {
        if (!scaleVal) return
        root.scale = String(scaleVal)
        var mon = activeMonitorObject
        if (mon) {
            var monName = mon.name
            var w = mon.width || (mon.lastIpcObject ? mon.lastIpcObject.width : 1920)
            var h = mon.height || (mon.lastIpcObject ? mon.lastIpcObject.height : 1080)
            var hz = currentRefreshRate
            var posX = (mon.x !== undefined) ? mon.x : 0
            var posY = (mon.y !== undefined) ? mon.y : 0
            if (Hyprland.usingLua) {
                var lua = 'hl.monitor({ output = "' + monName + '", mode = "' + w + 'x' + h + '@' + hz + '", position = "' + posX + 'x' + posY + '", scale = ' + scaleVal + ' })'
                Quickshell.execDetached(["hyprctl", "eval", lua])
            } else {
                Quickshell.execDetached(["hyprctl", "keyword", "monitor", monName + "," + w + "x" + h + "@" + hz + "," + posX + "x" + posY + "," + scaleVal])
            }
        }
        Quickshell.execDetached(["qdeck-monitor-scaling", String(scaleVal)])
        refreshDelayTimer.restart()
    }

    function setRefreshRate(targetHz) {
        if (!targetHz) return
        var mon = activeMonitorObject
        if (!mon) return
        var monName = mon.name
        var w = (mon.width !== undefined) ? mon.width : (mon.lastIpcObject && mon.lastIpcObject.width !== undefined ? mon.lastIpcObject.width : 1920)
        var h = (mon.height !== undefined) ? mon.height : (mon.lastIpcObject && mon.lastIpcObject.height !== undefined ? mon.lastIpcObject.height : 1080)
        var sc = (mon.scale !== undefined) ? mon.scale : (mon.lastIpcObject && mon.lastIpcObject.scale !== undefined ? mon.lastIpcObject.scale : 1)
        var posX = (mon.x !== undefined) ? mon.x : 0
        var posY = (mon.y !== undefined) ? mon.y : 0

        if (Hyprland.usingLua) {
            var lua = 'hl.monitor({ output = "' + monName + '", mode = "' + w + 'x' + h + '@' + targetHz + '", position = "' + posX + 'x' + posY + '", scale = ' + sc + ' })'
            Quickshell.execDetached(["hyprctl", "eval", lua])
        } else {
            Quickshell.execDetached(["hyprctl", "keyword", "monitor", monName + "," + w + "x" + h + "@" + targetHz + "," + posX + "x" + posY + "," + sc])
        }

        root._lastReportedHz = targetHz
        root._lastReportedMode = w + "x" + h + " @ " + targetHz + "Hz"
        root._pendingHz = targetHz
        root._pendingMode = w + "x" + h
        root._pendingMonName = monName

        refreshRateTimer.restart()
    }

    property int _pendingHz: 0
    property string _pendingMode: ""
    property string _pendingMonName: ""

    function toggleRefreshRate() {
        var maxHz = root.maxRefreshRate
        if (maxHz <= 60) return
        if (Math.abs(root.currentRefreshRate - 60) <= 2) {
            setRefreshRate(maxHz)
        } else {
            setRefreshRate(60)
        }
    }

    property Timer refreshRateTimer: Timer {
        interval: 350
        repeat: false
        onTriggered: {
            Hyprland.refreshMonitors()
            root.refresh()
            if (root._pendingHz > 0) {
                root.refreshRateChanged(root._pendingHz, root._pendingMode, root._pendingMonName)
                root._pendingHz = 0
            }
        }
    }

    function refresh() {
        if (!stateProc.running) stateProc.running = true
        if (!textSizeProc.running) textSizeProc.running = true
        Hyprland.refreshMonitors()
    }

    property Timer refreshDelayTimer: Timer {
        interval: 400
        repeat: false
        onTriggered: root.refresh()
    }

    property Process stateProc: Process {
        id: stateProc
        command: ["qdeck-monitor-state"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = String(text || "").split("\n")
                if (lines.length > 0) {
                    var bStr = String(lines[0] || "").trim()
                    if (bStr !== "" && bStr !== "unavailable") {
                        var b = parseInt(bStr, 10)
                        if (!isNaN(b)) {
                            root.brightness = Math.max(1, Math.min(100, b))
                            root.brightnessName = root.calculateBrightnessName(root.brightness)
                        }
                    }
                }
                if (lines.length > 5 && lines[5].trim() !== "") {
                    root.focusedMonitor = lines[5].trim()
                    root.deviceName = root.focusedMonitor
                }
                if (lines.length > 6 && lines[6].trim() !== "") {
                    var sc = lines[6].trim()
                    root.scale = sc
                }
            }
        }
    }

    property Process textSizeProc: Process {
        id: textSizeProc
        command: ["qdeck-display-text-size"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var out = String(text || "")
                var match = out.match(/text size:\s*(\d+)\s*px/i)
                if (match && match[1]) {
                    var s = parseInt(match[1], 10)
                    if (!isNaN(s)) {
                        root.textSize = s
                        Theme.baseTextSize = s
                    }
                }
            }
        }
    }

    // Real-time instant hardware backlight event listener via kernel udev
    property Process backlightWatchProc: Process {
        id: backlightWatchProc
        command: ["qdeck-backlight-monitor"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var pct = parseInt(line.trim(), 10)
                if (!isNaN(pct)) {
                    var clamped = Math.max(1, Math.min(100, pct))
                    root.brightness = clamped
                    root.brightnessName = root.calculateBrightnessName(clamped)
                    root.brightnessAdjusted(clamped)
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
