import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    visible: false

    // List of connected MPRIS players
    readonly property var players: Mpris.players ? Mpris.players.values : []
    property int stateRevision: 0

    Item {
        visible: false
        Repeater {
            model: Mpris.players
            Item {
                Connections {
                    target: modelData
                    function onPlaybackStateChanged() { root.stateRevision++ }
                    function onTrackChanged() { root.stateRevision++ }
                    function onPostTrackChanged() { root.stateRevision++ }
                }
            }
        }
    }

    // Actively selected player
    // Priority:
    // 1. A playing player that is not playerctld (real application)
    // 2. Any playing player
    // 3. A paused player with a track title that is not playerctld
    // 4. Any paused player with a track title
    // 5. Fallback to first player or null
    readonly property MprisPlayer activePlayer: {
        var _rev = root.stateRevision
        var list = root.players
        if (!list || list.length === 0) return null

        // 1. Playing non-playerctld
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (p && p.isPlaying && (!p.dbusName || p.dbusName.indexOf("playerctld") === -1)) {
                return p
            }
        }

        // 2. Any playing
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (p && p.isPlaying) return p
        }

        // 3. Paused non-playerctld with title
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (p && p.playbackState === MprisPlaybackState.Paused && p.trackTitle && (!p.dbusName || p.dbusName.indexOf("playerctld") === -1)) {
                return p
            }
        }

        // 4. Any paused with title
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (p && p.playbackState === MprisPlaybackState.Paused && p.trackTitle) {
                return p
            }
        }

        return list[0] || null
    }

    readonly property bool hasMedia: !!(activePlayer && (activePlayer.playbackState === MprisPlaybackState.Playing || activePlayer.playbackState === MprisPlaybackState.Paused) && (activePlayer.trackTitle || activePlayer.trackArtist))
    readonly property bool isPlaying: !!(activePlayer && activePlayer.isPlaying)

    readonly property string title: activePlayer && activePlayer.trackTitle ? activePlayer.trackTitle : "Unknown Title"
    readonly property string artist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : "Unknown Artist"
    readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
    readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
    readonly property string identity: activePlayer && activePlayer.identity ? activePlayer.identity : "Media Player"

    readonly property real length: (activePlayer && activePlayer.length > 0) ? activePlayer.length : 0
    property real position: (activePlayer && activePlayer.position > 0) ? activePlayer.position : 0

    readonly property real progress: (length > 0) ? Math.max(0, Math.min(1.0, position / length)) : 0

    readonly property bool canGoNext: !!(activePlayer && activePlayer.canGoNext)
    readonly property bool canGoPrevious: !!(activePlayer && activePlayer.canGoPrevious)
    readonly property bool canSeek: !!(activePlayer && activePlayer.canSeek)
    readonly property bool canControl: !!(activePlayer && activePlayer.canControl)
    readonly property bool canTogglePlaying: !!(activePlayer && activePlayer.canTogglePlaying)

    readonly property bool shuffleSupported: !!(activePlayer && activePlayer.shuffleSupported)
    readonly property bool shuffle: !!(activePlayer && activePlayer.shuffle)

    readonly property bool loopSupported: !!(activePlayer && activePlayer.loopSupported)
    readonly property int loopState: activePlayer ? activePlayer.loopState : MprisLoopState.None

    // Sync position on track change
    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackChanged() {
            if (root.activePlayer) {
                root.position = root.activePlayer.position
            }
        }
        function onPostTrackChanged() {
            if (root.activePlayer) {
                root.position = root.activePlayer.position
            }
        }
        function onPlaybackStateChanged() {
            if (root.activePlayer) {
                root.position = root.activePlayer.position
            }
        }
    }

    // High performance position timer (updates position every 500ms when playing)
    Timer {
        id: posTimer
        interval: 500
        repeat: true
        running: root.isPlaying
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged()
                root.position = root.activePlayer.position
            }
        }
    }

    function togglePlay() {
        if (!activePlayer) return
        if (activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying()
        } else if (activePlayer.isPlaying && activePlayer.canPause) {
            activePlayer.pause()
        } else if (!activePlayer.isPlaying && activePlayer.canPlay) {
            activePlayer.play()
        }
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext) activePlayer.next()
    }

    function previous() {
        if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous()
    }

    function seekTo(targetSec) {
        if (!activePlayer) return
        var target = Math.max(0, Math.min(length, targetSec))
        root.position = target
        if (activePlayer.canSeek) {
            if (activePlayer.positionSupported) {
                activePlayer.position = target
            } else {
                var diff = target - activePlayer.position
                activePlayer.seek(diff)
            }
        }
    }

    function toggleShuffle() {
        if (activePlayer && activePlayer.shuffleSupported && activePlayer.canControl) {
            activePlayer.shuffle = !activePlayer.shuffle
        }
    }

    function cycleLoop() {
        if (!activePlayer) return
        if (activePlayer.loopState === MprisLoopState.None) {
            activePlayer.loopState = MprisLoopState.Playlist
        } else if (activePlayer.loopState === MprisLoopState.Playlist) {
            activePlayer.loopState = MprisLoopState.Track
        } else {
            activePlayer.loopState = MprisLoopState.None
        }
    }

    function formatTime(sec) {
        if (isNaN(sec) || sec < 0) return "00:00"
        var s = Math.floor(sec)
        var m = Math.floor(s / 60)
        var remS = s % 60
        var mm = m < 10 ? "0" + m : "" + m
        var ss = remS < 10 ? "0" + remS : "" + remS
        return mm + ":" + ss
    }
}
