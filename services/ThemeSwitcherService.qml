import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property var themes: []
    property string currentTheme: ""
    property bool isSwitching: false
    property string switchingTo: ""
    property bool isOpen: false

    readonly property string listScriptPath: "qdeck-theme-switch"
    readonly property string currentThemeLink: Quickshell.env("HOME") + "/.config/themes/current"

    function refresh() {
        if (!listProc.running) {
            listProc.running = true
        }
    }

    function switchTheme(themeId) {
        if (!themeId) return
        root.isSwitching = true
        root.switchingTo = themeId

        // Execute theme switch script (theme-switch will also reload quickshell)
        Quickshell.execDetached([root.listScriptPath, "switch", themeId])

        switchResetTimer.restart()
    }

    function runSetup() {
        Quickshell.execDetached([root.listScriptPath, "setup"])
    }

    property Timer switchResetTimer: Timer {
        interval: 3500
        repeat: false
        onTriggered: {
            root.isSwitching = false
            root.switchingTo = ""
            root.refresh()
        }
    }

    readonly property int middleIndex: root.themes ? Math.floor(root.themes.length / 2) : 0

    function centerActiveTheme(list) {
        if (!list || list.length <= 1) return list || []
        var activeIdx = -1
        for (var i = 0; i < list.length; i++) {
            if (list[i].isCurrent) {
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
                            if (parsed[i].isCurrent) {
                                root.currentTheme = parsed[i].id
                                break
                            }
                        }
                        // Always center active theme in the middle
                        root.themes = root.centerActiveTheme(parsed)
                    }
                } catch (e) {
                    console.warn("[ThemeSwitcherService] Failed to parse themes JSON:", e)
                }
            }
        }
    }

    // Automatically refresh themes when colors change in Theme.qml
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
