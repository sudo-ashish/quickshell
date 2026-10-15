import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string activeProfile: "balanced"
    property string uptime: ""

    function setProfile(profile) {
        root.activeProfile = profile
        Quickshell.execDetached(["powerprofilesctl", "set", profile])
        refreshTimer.restart()
    }

    function lockSession() {
        Quickshell.execDetached(["loginctl", "lock-session"])
    }

    function suspendSystem() {
        Quickshell.execDetached(["systemctl", "suspend"])
    }

    function rebootSystem() {
        Quickshell.execDetached(["systemctl", "reboot"])
    }

    // Power menu state
    property bool powerMenuOpen: false

    // Power confirmation state
    property bool confirmOpen: false
    property string confirmAction: "" // "reboot" | "poweroff"
    property string confirmTitle: ""
    property string confirmMessage: ""
    property string confirmIcon: ""
    property var targetScreen: null

    function requestReboot(screen) {
        root.confirmAction = "reboot"
        root.confirmTitle = "Restart System"
        root.confirmMessage = "Are you sure you want to restart your computer?"
        root.confirmIcon = "󰑓"
        root.targetScreen = screen || null
        root.confirmOpen = true
    }

    function requestShutdown(screen) {
        root.confirmAction = "poweroff"
        root.confirmTitle = "Power Off"
        root.confirmMessage = "Are you sure you want to shut down your computer?"
        root.confirmIcon = "󰐥"
        root.targetScreen = screen || null
        root.confirmOpen = true
    }

    function cancelConfirm() {
        root.confirmOpen = false
        root.confirmAction = ""
    }

    function executeConfirmed() {
        var action = root.confirmAction
        root.confirmOpen = false
        root.confirmAction = ""
        if (action === "poweroff") {
            root.shutdownSystem()
        } else if (action === "reboot") {
            root.rebootSystem()
        }
    }

    function shutdownSystem() {
        Quickshell.execDetached(["systemctl", "poweroff"])
    }

    function refresh() {
        if (!profileProc.running) profileProc.running = true
        if (!uptimeProc.running) uptimeProc.running = true
    }

    property Process profileProc: Process {
        id: profileProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var p = text.trim()
                if (p) root.activeProfile = p
            }
        }
    }

    property Process uptimeProc: Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var u = text.trim()
                if (u) root.uptime = u
            }
        }
    }

    property Timer refreshTimer: Timer {
        id: refreshTimer
        interval: 500
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer pollTimer: Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
