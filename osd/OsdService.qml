import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Configurable Properties
    // ─────────────────────────────────────────────────────────────────────────
    property int volumeStep: 5
    property int maxVolume: 100
    property int brightnessStep: 5
    property int osdTimeout: 1500

    // Reference to visual OSD window
    property var osd: null

    // ─────────────────────────────────────────────────────────────────────────
    // IPC Interface (swayosd-client compatible vocabulary)
    // ─────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "osd"

        function outputVolume(action: string): void {
            root.handleOutputVolume(action)
        }

        function inputVolume(action: string): void {
            root.handleInputVolume(action)
        }

        function brightness(action: string): void {
            root.handleBrightness(action)
        }

        function refreshRate(hz: string): string {
            if (root.osd && root.osd.showToast) {
                var clean = String(hz || "").trim()
                var msg = clean.indexOf("Hz") !== -1 ? clean : (clean + "Hz")
                root.osd.showToast("󰍹", msg, 2000)
            }
            return "ok"
        }

        // Generic / backwards-compatibility methods for qdeck-osd / scripts
        function display(payloadJson: string): string {
            if (root.osd && root.osd.open) {
                root.osd.open(payloadJson)
            }
            return "ok"
        }

        function trigger(icon: string, msg: string): string {
            if (root.osd && root.osd.showToast) {
                root.osd.showToast(icon, msg, root.osdTimeout)
            }
            return "ok"
        }

        function close(): string {
            if (root.osd && root.osd.close) {
                root.osd.close()
            }
            return "ok"
        }

        function state(): string {
            return (root.osd && root.osd.opened) ? "open" : "closed"
        }

        function ping(): string {
            return "ok"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Queue & Action Dispatcher
    // ─────────────────────────────────────────────────────────────────────────
    property var taskQueue: []
    property bool isBusy: false
    property var activeTask: null

    function parseAction(action: string, defaultStep: int) {
        if (!action) return null
        var a = action.trim().toLowerCase()
        if (a === "mute-toggle" || a === "toggle-mute" || a === "mute" || a === "toggle") {
            return { type: "mute-toggle", step: 0 }
        }

        var step = defaultStep
        var isRaise = false
        var isLower = false

        if (a === "raise-fine" || a === "raise 1" || a === "raise-1" || a === "+1" || a === "+1%") {
            isRaise = true
            step = 1
        } else if (a === "lower-fine" || a === "lower 1" || a === "lower-1" || a === "-1" || a === "-1%") {
            isLower = true
            step = 1
        } else if (a.startsWith("raise") || a.startsWith("+")) {
            isRaise = true
            var m = a.match(/(?:raise|\+)\s*(\d+)/)
            if (m) {
                var val = parseInt(m[1], 10)
                if (val > 0) step = val
            }
        } else if (a.startsWith("lower") || a.startsWith("-")) {
            isLower = true
            var m2 = a.match(/(?:lower|\-)\s*(\d+)/)
            if (m2) {
                var val2 = parseInt(m2[1], 10)
                if (val2 > 0) step = val2
            }
        }

        if (isRaise) return { type: "raise", step: step }
        if (isLower) return { type: "lower", step: step }
        return null
    }

    function handleOutputVolume(action: string) {
        var parsed = parseAction(action, root.volumeStep)
        if (!parsed) {
            console.warn("[OSD] Unknown action for outputVolume:", action)
            return
        }
        enqueueTask({ domain: "volume", action: parsed.type, step: parsed.step })
    }

    function handleInputVolume(action: string) {
        var parsed = parseAction(action, root.volumeStep)
        if (!parsed || parsed.type !== "mute-toggle") {
            console.warn("[OSD] Unknown action for inputVolume:", action)
            return
        }
        enqueueTask({ domain: "mic", action: "mute-toggle", step: 0 })
    }

    function handleBrightness(action: string) {
        var parsed = parseAction(action, root.brightnessStep)
        if (!parsed) {
            console.warn("[OSD] Unknown action for brightness:", action)
            return
        }
        enqueueTask({ domain: "brightness", action: parsed.type, step: parsed.step })
    }

    function enqueueTask(task) {
        taskQueue.push(task)
        processQueue()
    }

    function processQueue() {
        if (root.isBusy) return
        if (taskQueue.length === 0) return

        var first = taskQueue[0]

        // Coalesce rapid volume repeat (raise/lower)
        if (first.domain === "volume" && (first.action === "raise" || first.action === "lower")) {
            var netDelta = 0
            while (taskQueue.length > 0 && taskQueue[0].domain === "volume" && (taskQueue[0].action === "raise" || taskQueue[0].action === "lower")) {
                var item = taskQueue.shift()
                var s = (item.step !== undefined && item.step > 0) ? item.step : root.volumeStep
                netDelta += (item.action === "raise" ? s : -s)
            }
            if (netDelta === 0) {
                processQueue()
                return
            }

            var netPercent = Math.abs(netDelta)
            var setCmd = []
            if (netDelta > 0) {
                var limitStr = (root.maxVolume / 100.0).toFixed(2)
                setCmd = ["wpctl", "set-volume", "-l", limitStr, "@DEFAULT_AUDIO_SINK@", netPercent + "%+"]
            } else {
                setCmd = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", netPercent + "%-"]
            }

            executeTask({
                domain: "volume",
                setCommand: setCmd,
                getCommand: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
            })
            return
        }

        // Coalesce rapid brightness repeat (raise/lower)
        if (first.domain === "brightness" && (first.action === "raise" || first.action === "lower")) {
            var bNetDelta = 0
            while (taskQueue.length > 0 && taskQueue[0].domain === "brightness" && (taskQueue[0].action === "raise" || taskQueue[0].action === "lower")) {
                var bItem = taskQueue.shift()
                var bs = (bItem.step !== undefined && bItem.step > 0) ? bItem.step : root.brightnessStep
                bNetDelta += (bItem.action === "raise" ? bs : -bs)
            }
            if (bNetDelta === 0) {
                processQueue()
                return
            }

            var bNetPercent = Math.abs(bNetDelta)
            var bSign = bNetDelta > 0 ? "%+" : "%-"
            var bSetCmd = ["brightnessctl", "set", bNetPercent + bSign]

            executeTask({
                domain: "brightness",
                setCommand: bSetCmd,
                getCommand: ["brightnessctl", "-m"]
            })
            return
        }

        // Single actions: mute-toggle
        var singleTask = taskQueue.shift()
        if (singleTask.domain === "volume" && singleTask.action === "mute-toggle") {
            executeTask({
                domain: "volume",
                setCommand: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"],
                getCommand: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
            })
        } else if (singleTask.domain === "mic" && singleTask.action === "mute-toggle") {
            executeTask({
                domain: "mic",
                setCommand: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"],
                getCommand: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
            })
        }
    }

    function executeTask(task) {
        root.isBusy = true
        root.activeTask = task
        root.activeTask.displayed = false
        setProc.exec(task.setCommand)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase 1: Mutate State via Process
    // ─────────────────────────────────────────────────────────────────────────
    Process {
        id: setProc
        running: false

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("[OSD] Set command failed with exitCode:", exitCode, "cmd:", command)
                root.finishTask(false)
                return
            }

            // Phase 2: Read resulting post-change state
            if (root.activeTask && root.activeTask.getCommand) {
                getProc.exec(root.activeTask.getCommand)
            } else {
                root.finishTask(true)
            }
        }
    }

    // Auto-bridge socket instance into both XDG config and workspace hash paths
    Process {
        id: bridgeProc
        running: false
        command: [
            "sh", "-c",
            "uid=$(id -u); " +
            "mkdir -p /run/user/$uid/quickshell/by-shell/3bb4e7c6d4dad9dfd3f25bf68311dcd8 /run/user/$uid/quickshell/by-shell/297537087f24e658cd0a0b2380d3bfef; " +
            "for id in /run/user/$uid/quickshell/by-id/*; do [ -e \"$id\" ] || continue; " +
            "b=$(basename \"$id\"); " +
            "ln -sf \"$id\" /run/user/$uid/quickshell/by-shell/3bb4e7c6d4dad9dfd3f25bf68311dcd8/\"$b\"; " +
            "ln -sf \"$id\" /run/user/$uid/quickshell/by-shell/297537087f24e658cd0a0b2380d3bfef/\"$b\"; " +
            "done"
        ]
    }

    Timer {
        id: bridgeTimer
        interval: 400
        repeat: false
        running: true
        onTriggered: {
            bridgeProc.exec(bridgeProc.command)
        }
    }

    Component.onCompleted: {
        bridgeProc.exec(bridgeProc.command)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase 2: Read & Parse Real Result via Process & StdioCollector
    // ─────────────────────────────────────────────────────────────────────────
    Process {
        id: getProc
        running: false

        stdout: StdioCollector {
            id: getCollector
            onStreamFinished: {
                if (root.activeTask && !root.activeTask.displayed) {
                    root.parseAndDisplay(getCollector.text || "")
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("[OSD] Get command failed with exitCode:", exitCode, "cmd:", command)
                root.finishTask(false)
                return
            }
            if (root.activeTask && !root.activeTask.displayed) {
                root.parseAndDisplay(getCollector.text || "")
            }
            root.finishTask(true)
        }
    }

    function finishTask(success) {
        root.isBusy = false
        root.activeTask = null
        // Drain any remaining queued actions
        root.processQueue()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Output Parsing & Presentation
    // ─────────────────────────────────────────────────────────────────────────
    function parseAndDisplay(output) {
        if (!root.activeTask || !root.osd || root.activeTask.displayed) return
        root.activeTask.displayed = true

        var domain = root.activeTask.domain

        if (domain === "volume") {
            var isMuted = output.indexOf("[MUTED]") !== -1
            var match = output.match(/Volume:\s*([0-9]+(?:\.[0-9]+)?)/)
            var rawVal = match ? parseFloat(match[1]) : 0.0
            var percent = Math.round(rawVal * 100)

            var icon = "󰕾"
            if (isMuted || percent === 0) {
                icon = "󰝟"
            } else if (percent < 33) {
                icon = "󰕿"
            } else if (percent < 66) {
                icon = "󰖀"
            }

            root.osd.showOsd(
                icon,
                isMuted ? "Muted" : (percent + "%"),
                percent,
                root.maxVolume,
                true,
                isMuted,
                percent > 100,
                root.osdTimeout
            )
        } else if (domain === "mic") {
            var micMuted = output.indexOf("[MUTED]") !== -1
            var micIcon = micMuted ? "󰍭" : "󰍬"
            var micText = micMuted ? "Muted" : "Unmuted"

            root.osd.showOsd(
                micIcon,
                micText,
                0,
                100,
                false,
                micMuted,
                false,
                root.osdTimeout
            )
        } else if (domain === "brightness") {
            var bPercent = -1
            var bMatch = output.match(/\b(\d+)%/)
            if (bMatch) {
                bPercent = parseInt(bMatch[1], 10)
            } else {
                var parts = output.trim().split(",")
                if (parts.length >= 4) {
                    var parsed = parseInt(parts[3], 10)
                    if (!isNaN(parsed)) bPercent = parsed
                }
            }

            if (bPercent < 0) {
                console.warn("[OSD] Failed to parse brightness from output:", output)
                return
            }

            var bIcon = "󰃠"
            if (bPercent < 33) {
                bIcon = "󰃞"
            } else if (bPercent < 66) {
                bIcon = "󰃟"
            }

            root.osd.showOsd(
                bIcon,
                bPercent + "%",
                bPercent,
                100,
                true,
                false,
                false,
                root.osdTimeout
            )
        }
    }
}
