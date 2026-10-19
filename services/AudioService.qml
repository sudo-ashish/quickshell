import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../theme"
import "AudioModel.js" as Model

QtObject {
    id: root

    signal requestToggleMenu()
    signal volumeAdjusted(int value, bool isMuted)

    property IpcHandler ipcHandler: IpcHandler {
        target: "audio"
        function toggle(): string {
            root.requestToggleMenu()
            return "ok"
        }
        function open(): string {
            root.requestToggleMenu()
            return "ok"
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

    function isBluetoothNode(node) {
        if (!node) return false
        var n = String(node.name || "").toLowerCase()
        return (n.indexOf("bluez") !== -1 || n.indexOf("bluetooth") !== -1)
    }

    readonly property bool hasValidSink: !!(sink && sink.audio && sink.audio.volume !== undefined)

    property int lastValidVolume: 50
    readonly property int volume: {
        if (hasValidSink) {
            var rawVol = sink.audio.volume
            var v = Math.max(0, Math.min(100, Math.round(rawVol * 100)))
            // If current sink is bluetooth and volume suddenly drops to 0, that's a disconnect teardown!
            if (v === 0 && lastValidVolume > 0 && isBluetoothNode(sink)) {
                root.sinkSwitching = true
                sinkSwitchTimer.restart()
                return lastValidVolume
            }
            lastValidVolume = v
            return v
        }
        return lastValidVolume
    }

    property bool lastValidMuted: false
    readonly property bool muted: {
        if (sink && sink.audio && sink.audio.muted !== undefined) {
            var m = !!sink.audio.muted
            lastValidMuted = m
            return m
        }
        return lastValidMuted
    }

    readonly property int inputVolume: source && source.audio ? Math.round(source.audio.volume * 100) : 0
    readonly property bool inputMuted: source && source.audio ? source.audio.muted : false

    readonly property string volumeName: Model.outputVolumeName(sink && sink.audio ? sink.audio.volume : 0, muted)

    property bool sinkSwitching: false
    property Timer sinkSwitchTimer: Timer {
        interval: 4500
        repeat: false
        onTriggered: root.sinkSwitching = false
    }

    property string lastSinkName: ""
    property int lastSinkId: -1
    onSinkChanged: {
        root.sinkSwitching = true
        sinkSwitchTimer.restart()
        var currentName = sink && sink.name ? String(sink.name) : ""
        var currentId = sink && sink.id !== undefined ? sink.id : -1
        if (currentName !== "") {
            lastSinkName = currentName
        }
        lastSinkId = currentId
    }

    readonly property string icon: {
        if (!sink || !sink.audio) return Icons.volumeMute
        return Icons.volumeLevel(volume, muted, Model.isHeadphones(sink))
    }

    readonly property string inputIcon: {
        if (!source || !source.audio) return Icons.micOff
        return Icons.micLevel(inputMuted)
    }

    readonly property bool anyAudible: (!muted && volume > 0) || (!inputMuted && inputVolume > 0)

    // Sink Availability (filter unplugged/inactive HDMI outputs)
    property var sinkAvailability: ({})
    property bool sinkAvailabilityLoaded: false

    function sinkAvailable(node) {
        if (!node || !node.name) return false
        var name = String(node.name)
        if (sinkAvailability[name] === false) return false
        if (sinkAvailability[name] === true) return true
        // If availability is still loading, hide HDMI outputs until confirmed plugged in
        if (!sinkAvailabilityLoaded) {
            var lower = name.toLowerCase()
            if (lower.indexOf("hdmi") !== -1 || lower.indexOf("displayport") !== -1) {
                return false
            }
        }
        return true
    }

    function updateSinkAvailability(raw) {
        sinkAvailability = Model.parseSinkAvailability(raw)
        sinkAvailabilityLoaded = true
    }

    // Uses pactl (PipeWire-pulse) to detect which sinks are plugged in.
    // pactl is part of pipewire-pulse (standard on all Arch installs with PipeWire).
    property Process sinkAvailabilityProc: Process {
        id: sinkAvailabilityProc
        command: ["pactl", "list", "sinks"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateSinkAvailability(text)
        }
    }

    property Timer sinkAvailTimer: Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!sinkAvailabilityProc.running) sinkAvailabilityProc.running = true
    }

    // Raw candidate nodes
    readonly property var candidateSinks: {
        var list = []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && n.isSink && !n.isStream) list.push(n)
        }
        return list
    }

    readonly property var candidateSources: {
        var list = []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && !n.isSink && !n.isStream && Model.isAudioSource(n)) {
                var name = n.name || ""
                if (name === "quickshell") continue
                list.push(n)
            }
        }
        return list
    }

    readonly property var candidateStreams: {
        var list = []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (!n || !n.isStream || !Model.isPlaybackStream(n)) continue
            var name = String(n.name || "")
            // Filter internal quickshell audio passthrough nodes
            if (name === "quickshell" || name.indexOf("qs_internal") === 0) continue
            list.push(n)
        }
        return list
    }

    // PwObjectTracker ensures Quickshell observes and binds audio properties on these nodes
    property PwObjectTracker sinkTracker: PwObjectTracker { objects: root.candidateSinks }
    property PwObjectTracker sourceTracker: PwObjectTracker { objects: root.candidateSources }
    property PwObjectTracker streamTracker: PwObjectTracker { objects: root.candidateStreams }

    // Sinks list for UI (only available / plugged in sinks)
    readonly property var sinks: {
        var list = []
        for (var i = 0; i < candidateSinks.length; i++) {
            var n = candidateSinks[i]
            if (!sinkAvailable(n)) continue
            var isDef = !!(sink && n.id === sink.id)
            list.push({
                id: n.id,
                node: n,
                name: n.name || "",
                displayName: Model.nodeLabel(n),
                glyph: Model.sinkGlyph(n),
                isDefault: isDef
            })
        }
        if (sink && list.length === 0) {
            list.push({
                id: sink.id,
                node: sink,
                name: sink.name || "",
                displayName: Model.nodeLabel(sink),
                glyph: Model.sinkGlyph(sink),
                isDefault: true
            })
        }
        return list
    }

    // Sources list (Microphones) for UI
    readonly property var sources: {
        var list = []
        for (var i = 0; i < candidateSources.length; i++) {
            var n = candidateSources[i]
            var isDef = !!(source && n.id === source.id)
            list.push({
                id: n.id,
                node: n,
                name: n.name || "",
                displayName: Model.nodeLabel(n),
                glyph: Model.sourceGlyph(n),
                isDefault: isDef
            })
        }
        return list
    }

    // Application Playback Streams for UI (Stable PwNode references)
    readonly property var audioStreams: {
        var list = []
        for (var i = 0; i < candidateStreams.length; i++) {
            var n = candidateStreams[i]
            if (n && n.audio) list.push(n)
        }
        return list
    }

    // Application Playback Streams dictionary (for compatibility)
    readonly property var streams: {
        var list = []
        for (var i = 0; i < candidateStreams.length; i++) {
            var n = candidateStreams[i]
            if (!n.audio) continue
            list.push({
                id: n.id,
                node: n,
                displayName: Model.streamLabel(n) || "App",
                volume: Math.round((n.audio ? n.audio.volume : 0) * 100),
                muted: !!(n.audio && n.audio.muted)
            })
        }
        return list
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

    function setVolume(percent) {
        root.inhibitOsd(2000)
        var clamped = Math.max(0, Math.min(100, Math.round(percent)))
        if (sink && sink.audio) {
            sink.audio.volume = clamped / 100.0
        }
        var val = (clamped / 100.0).toFixed(2)
        Quickshell.execDetached(["wpctl", "--no-osd", "set-volume", "@DEFAULT_AUDIO_SINK@", val])
        root.volumeAdjusted(clamped, root.muted)
    }

    function toggleMute() {
        root.inhibitOsd(2000)
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted
        }
        Quickshell.execDetached(["wpctl", "--no-osd", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        root.volumeAdjusted(root.volume, root.muted)
    }

    function setInputVolume(percent) {
        root.inhibitOsd(2000)
        var clamped = Math.max(0, Math.min(100, Math.round(percent)))
        if (source && source.audio) {
            source.audio.volume = clamped / 100.0
        }
        var val = (clamped / 100.0).toFixed(2)
        Quickshell.execDetached(["wpctl", "--no-osd", "set-volume", "@DEFAULT_AUDIO_SOURCE@", val])
    }

    function toggleInputMute() {
        root.inhibitOsd(2000)
        if (source && source.audio) {
            source.audio.muted = !source.audio.muted
        }
        Quickshell.execDetached(["wpctl", "--no-osd", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
    }

    function toggleAllMuted() {
        root.inhibitOsd(2000)
        var shouldMute = anyAudible
        if (sink && sink.audio) sink.audio.muted = shouldMute
        if (source && source.audio) source.audio.muted = shouldMute
        Quickshell.execDetached(["wpctl", "--no-osd", "set-mute", "@DEFAULT_AUDIO_SINK@", shouldMute ? "1" : "0"])
        Quickshell.execDetached(["wpctl", "--no-osd", "set-mute", "@DEFAULT_AUDIO_SOURCE@", shouldMute ? "1" : "0"])
    }

    function setDefaultSink(node) {
        if (!node) return
        Pipewire.preferredDefaultAudioSink = node
        if (node.id !== undefined) {
            Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
        }
    }

    function setDefaultSource(node) {
        if (!node) return
        Pipewire.preferredDefaultAudioSource = node
        if (node.id !== undefined) {
            Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
        }
    }

    function setStreamVolume(streamNode, percent) {
        root.inhibitOsd(2000)
        if (!streamNode || !streamNode.audio) return
        var clamped = Math.max(0, Math.min(150, Math.round(percent)))
        streamNode.audio.volume = clamped / 100.0
    }

    function toggleStreamMute(streamNode) {
        root.inhibitOsd(2000)
        if (!streamNode || !streamNode.audio) return
        streamNode.audio.muted = !streamNode.audio.muted
        if (streamNode.id !== undefined) {
            Quickshell.execDetached(["wpctl", "--no-osd", "set-mute", String(streamNode.id), "toggle"])
        }
    }

    function refresh() {
        if (!sinkAvailabilityProc.running) sinkAvailabilityProc.running = true
    }

    Component.onCompleted: {
        lastSinkName = sink && sink.name ? String(sink.name) : ""
    }
}
