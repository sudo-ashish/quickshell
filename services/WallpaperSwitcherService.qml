import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property var wallpapers: []
    property string activeWallpaper: ""
    property bool isSwitching: false
    property string switchingTo: ""
    property bool isOpen: false

    readonly property string listScriptPath: "qdeck-wallpaper"
    readonly property int middleIndex: root.wallpapers ? Math.floor(root.wallpapers.length / 2) : 0

    function refresh() {
        if (!listProc.running) {
            listProc.running = true
        }
    }

    function switchWallpaper(wallpaperPath) {
        if (!wallpaperPath) return
        root.isSwitching = true
        root.switchingTo = wallpaperPath

        // Execute wallpaper-switch script via helper
        Quickshell.execDetached([root.listScriptPath, "switch", wallpaperPath])

        switchResetTimer.restart()
    }

    function centerActiveWallpaper(list) {
        if (!list || list.length <= 1) return list || []
        var activeIdx = -1
        for (var i = 0; i < list.length; i++) {
            if (list[i].isActive) {
                activeIdx = i
                break
            }
        }
        if (activeIdx === -1) return list

        var n = list.length
        var targetMid = Math.floor(n / 2)
        var shift = (activeIdx - targetMid + n) % n
        if (shift === 0) return list

        var rotated = []
        for (var j = 0; j < n; j++) {
            rotated.push(list[(j + shift) % n])
        }
        return rotated
    }

    property Timer switchResetTimer: Timer {
        interval: 1500
        repeat: false
        onTriggered: {
            root.isSwitching = false
            root.switchingTo = ""
            root.refresh()
        }
    }

    property Process listProc: Process {
        id: listProc
        command: [root.listScriptPath, "list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = text.trim()
                if (!raw) return
                try {
                    var parsed = JSON.parse(raw)
                    if (Array.isArray(parsed)) {
                        for (var i = 0; i < parsed.length; i++) {
                            if (parsed[i].isActive) {
                                root.activeWallpaper = parsed[i].path
                                break
                            }
                        }
                        // Always center active wallpaper in the middle
                        root.wallpapers = root.centerActiveWallpaper(parsed)
                    }
                } catch (e) {
                    console.warn("[WallpaperSwitcherService] Failed to parse wallpapers JSON:", e)
                }
            }
        }
    }

    // Refresh wallpapers when theme changes
    property Connections themeWatcher: Connections {
        target: Theme
        function on_CChanged() {
            root.refresh()
        }
    }

    Component.onCompleted: {
        root.refresh()
    }
}
