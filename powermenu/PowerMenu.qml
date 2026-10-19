import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../services"

PanelWindow {
    id: root

    property PowerService powerService: null
    property ThemeSwitcherService themeService: null
    property WallpaperSwitcherService wallpaperService: null

    property bool isOpen: false
    property string currentView: "power" // "power" | "theme" | "wallpaper"
    property real animProgress: 0.0

    // Transitions between views are only allowed when the menu is actively open and settled
    readonly property bool viewTransitionsEnabled: root.isOpen && !openAnim.running && !closeAnim.running

    // Selection indices
    property int powerIndex: 0
    property int themeIndex: 0
    property int wallpaperIndex: 0

    // Corner radius settings
    property int activeRadius: Appearance.powerMenuRadiusActive
    property int inactiveRadius: Appearance.powerMenuRadiusInactive

    // Theme service bindings
    readonly property var themes: root.themeService ? root.themeService.themes : []
    readonly property int themesCount: root.themes ? root.themes.length : 0
    readonly property string currentTheme: root.themeService ? root.themeService.currentTheme : ""

    // Wallpaper service bindings
    readonly property var wallpapers: root.wallpaperService ? root.wallpaperService.wallpapers : []
    readonly property int wallpapersCount: root.wallpapers ? root.wallpapers.length : 0
    readonly property string activeWallpaper: root.wallpaperService ? root.wallpaperService.activeWallpaper : ""

    // Target animated dimensions for the single unified surface (show up to 5 items)
    readonly property real targetWidth: {
        if (root.currentView === "power") return Appearance.powerMenuWidthPower
        if (root.currentView === "theme") {
            var tCount = Math.min(5, Math.max(1, root.themesCount))
            return Math.min(root.width - 48, Math.max(Appearance.powerMenuHeightTheme * 2.14, (tCount * 196) + ((tCount - 1) * 12) + 28))
        }
        // wallpaper view
        var wCount = Math.min(5, Math.max(1, root.wallpapersCount))
        return Math.min(root.width - 48, Math.max(Appearance.powerMenuHeightTheme * 2.14, (wCount * 196) + ((wCount - 1) * 12) + 28))
    }

    // Dynamic target height: 136 for power, 196 for 16:9 wallpaper list, 252 for theme list
    readonly property real targetHeight: (root.currentView === "power")
        ? Appearance.powerMenuHeightPower
        : ((root.currentView === "wallpaper") ? Appearance.powerMenuHeightWallpaper : Appearance.powerMenuHeightTheme)

    // Keep window mapped while closing animation completes
    visible: root.isOpen || closeAnim.running

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // Bind dynamically to focused monitor
    screen: {
        if (!Quickshell.screens || Quickshell.screens.length === 0) return null
        var foc = Hyprland.focusedMonitor
        if (foc && foc.name) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === foc.name) {
                    return Quickshell.screens[i]
                }
            }
        }
        return Quickshell.screens[0]
    }

    // LayerShell configuration
    WlrLayershell.namespace: "quickshell-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Spring pop-up & retraction physics from bottom
    NumberAnimation {
        id: openAnim
        target: root
        property: "animProgress"
        to: 1.0
        duration: 320
        easing.type: Easing.OutBack
        easing.overshoot: 1.15
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "animProgress"
        to: 0.0
        duration: 200
        easing.type: Easing.InCubic
        onFinished: {
            root.animProgress = 0.0
            if (!root.isOpen) {
                if (root.powerService) root.powerService.powerMenuOpen = false
                if (root.themeService) root.themeService.isOpen = false
                if (root.wallpaperService) root.wallpaperService.isOpen = false
                // Reset view back to default power menu when fully closed so no old view lingers
                root.currentView = "power"
                root.powerIndex = 0
            }
        }
    }

    function openPower() {
        closeAnim.stop()
        root.currentView = "power"
        root.powerIndex = 0
        if (root.powerService) root.powerService.powerMenuOpen = true
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function openTheme() {
        closeAnim.stop()
        if (root.themeService) {
            root.themeService.refresh()
            root.themeService.isOpen = true
        }
        root.currentView = "theme"
        root.themeIndex = (root.themeService && root.themeService.middleIndex !== undefined)
            ? root.themeService.middleIndex
            : Math.floor(root.themesCount / 2)
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Center)
        })
    }

    function openWallpaper() {
        closeAnim.stop()
        if (root.wallpaperService) {
            root.wallpaperService.refresh()
            root.wallpaperService.isOpen = true
        }
        root.currentView = "wallpaper"
        root.wallpaperIndex = (root.wallpaperService && root.wallpaperService.middleIndex !== undefined)
            ? root.wallpaperService.middleIndex
            : Math.floor(root.wallpapersCount / 2)
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Center)
        })
    }

    function close() {
        openAnim.stop()
        root.isOpen = false
        if (root.powerService) root.powerService.powerMenuOpen = false
        if (root.themeService) root.themeService.isOpen = false
        if (root.wallpaperService) root.wallpaperService.isOpen = false
        closeAnim.restart()
    }

    function togglePower() {
        if (!root.isOpen) {
            root.openPower()
        } else if (root.currentView === "power") {
            root.close()
        } else {
            root.currentView = "power"
            root.powerIndex = 0
            keyCatcher.forceActiveFocus()
        }
    }

    function toggleTheme() {
        if (!root.isOpen) {
            root.openTheme()
        } else if (root.currentView === "theme") {
            root.close()
        } else {
            if (root.themeService) root.themeService.refresh()
            root.currentView = "theme"
            root.themeIndex = (root.themeService && root.themeService.middleIndex !== undefined)
                ? root.themeService.middleIndex
                : Math.floor(root.themesCount / 2)
            keyCatcher.forceActiveFocus()
            if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Center)
        }
    }

    function toggleWallpaper() {
        if (!root.isOpen) {
            root.openWallpaper()
        } else if (root.currentView === "wallpaper") {
            root.close()
        } else {
            if (root.wallpaperService) root.wallpaperService.refresh()
            root.currentView = "wallpaper"
            root.wallpaperIndex = (root.wallpaperService && root.wallpaperService.middleIndex !== undefined)
                ? root.wallpaperService.middleIndex
                : Math.floor(root.wallpapersCount / 2)
            keyCatcher.forceActiveFocus()
            if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Center)
        }
    }

    function selectNextTheme() {
        if (root.themesCount <= 0) return
        root.themeIndex = (root.themeIndex + 1) % root.themesCount
        if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Contain)
    }

    function selectPrevTheme() {
        if (root.themesCount <= 0) return
        root.themeIndex = (root.themeIndex - 1 + root.themesCount) % root.themesCount
        if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Contain)
    }

    function applyTheme(themeId) {
        if (!themeId) return
        if (root.themeService) {
            root.themeService.switchTheme(themeId)
        }
        themeCloseTimer.restart()
    }

    function selectNextWallpaper() {
        if (root.wallpapersCount <= 0) return
        root.wallpaperIndex = (root.wallpaperIndex + 1) % root.wallpapersCount
        if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Contain)
    }

    function selectPrevWallpaper() {
        if (root.wallpapersCount <= 0) return
        root.wallpaperIndex = (root.wallpaperIndex - 1 + root.wallpapersCount) % root.wallpapersCount
        if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Contain)
    }

    function applyWallpaper(wallpaperPath) {
        if (!wallpaperPath) return
        if (root.wallpaperService) {
            root.wallpaperService.switchWallpaper(wallpaperPath)
        }
        themeCloseTimer.restart()
    }

    Timer {
        id: themeCloseTimer
        interval: 220
        repeat: false
        onTriggered: root.close()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IPC Handler for Power Menu (qdeck-powermenu)
    // ─────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "powermenu"

        function open(): string {
            root.openPower()
            return "ok"
        }

        function close(): string {
            root.close()
            return "ok"
        }

        function toggle(): string {
            root.togglePower()
            return (root.isOpen && root.currentView === "power") ? "open" : "closed"
        }

        function next(): string {
            root.powerIndex = (root.powerIndex + 1) % 4
            return String(root.powerIndex)
        }

        function prev(): string {
            root.powerIndex = (root.powerIndex - 1 + 4) % 4
            return String(root.powerIndex)
        }

        function select(idx: string): string {
            var n = parseInt(idx, 10)
            if (!isNaN(n) && n >= 0 && n < 4) {
                root.powerIndex = n
            }
            return String(root.powerIndex)
        }

        function getState(): string {
            return JSON.stringify({
                isOpen: root.isOpen,
                currentView: root.currentView,
                animProgress: root.animProgress,
                selectedIndex: root.powerIndex,
                selectedAction: root.actions[root.powerIndex].id,
                actions: ["lock", "logout", "restart", "shutdown"],
                baseOpacity: Theme.baseOpacity,
                blurEnabled: Theme.blurEnabled
            })
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IPC Handler for Theme Switcher (qdeck-themeswitcher)
    // ─────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "themeswitcher"

        function open(): string {
            root.openTheme()
            return "ok"
        }

        function close(): string {
            root.close()
            return "ok"
        }

        function toggle(): string {
            root.toggleTheme()
            return (root.isOpen && root.currentView === "theme") ? "open" : "closed"
        }

        function next(): string {
            root.selectNextTheme()
            return String(root.themeIndex)
        }

        function prev(): string {
            root.selectPrevTheme()
            return String(root.themeIndex)
        }

        function select(idx: string): string {
            var n = parseInt(idx, 10)
            if (!isNaN(n) && n >= 0 && n < root.themesCount) {
                root.themeIndex = n
                if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Contain)
            }
            return String(root.themeIndex)
        }

        function apply(themeName: string): string {
            var targetId = String(themeName || "").trim()
            if (!targetId && root.themeIndex >= 0 && root.themeIndex < root.themesCount) {
                targetId = root.themes[root.themeIndex].id
            }
            if (targetId) {
                root.applyTheme(targetId)
                return "applied " + targetId
            }
            return "error: missing theme"
        }

        function getState(): string {
            var sel = (root.themeIndex >= 0 && root.themeIndex < root.themesCount) ? root.themes[root.themeIndex] : null
            return JSON.stringify({
                isOpen: root.isOpen,
                currentView: root.currentView,
                animProgress: root.animProgress,
                selectedIndex: root.themeIndex,
                selectedTheme: sel ? sel.id : null,
                selectedThemeName: sel ? sel.name : null,
                currentTheme: root.currentTheme,
                themesCount: root.themesCount,
                baseOpacity: Theme.baseOpacity,
                blurEnabled: Theme.blurEnabled
            })
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IPC Handler for Wallpaper Switcher (qdeck-wallpaperswitcher)
    // ─────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "wallpaperswitcher"

        function open(): string {
            root.openWallpaper()
            return "ok"
        }

        function close(): string {
            root.close()
            return "ok"
        }

        function toggle(): string {
            root.toggleWallpaper()
            return (root.isOpen && root.currentView === "wallpaper") ? "open" : "closed"
        }

        function next(): string {
            root.selectNextWallpaper()
            return String(root.wallpaperIndex)
        }

        function prev(): string {
            root.selectPrevWallpaper()
            return String(root.wallpaperIndex)
        }

        function select(idx: string): string {
            var n = parseInt(idx, 10)
            if (!isNaN(n) && n >= 0 && n < root.wallpapersCount) {
                root.wallpaperIndex = n
                if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Contain)
            }
            return String(root.wallpaperIndex)
        }

        function apply(wallpaperPath: string): string {
            var targetPath = String(wallpaperPath || "").trim()
            if (!targetPath && root.wallpaperIndex >= 0 && root.wallpaperIndex < root.wallpapersCount) {
                targetPath = root.wallpapers[root.wallpaperIndex].path
            }
            if (targetPath) {
                root.applyWallpaper(targetPath)
                return "applied " + targetPath
            }
            return "error: missing wallpaper"
        }

        function getState(): string {
            var sel = (root.wallpaperIndex >= 0 && root.wallpaperIndex < root.wallpapersCount) ? root.wallpapers[root.wallpaperIndex] : null
            return JSON.stringify({
                isOpen: root.isOpen,
                currentView: root.currentView,
                animProgress: root.animProgress,
                selectedIndex: root.wallpaperIndex,
                selectedWallpaper: sel ? sel.path : null,
                selectedWallpaperName: sel ? sel.name : null,
                activeWallpaper: root.activeWallpaper,
                wallpapersCount: root.wallpapersCount,
                baseOpacity: Theme.baseOpacity,
                blurEnabled: Theme.blurEnabled
            })
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Soft Backdrop Scrim & Click Catcher
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)
        opacity: root.animProgress

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Hyprland focus grab disabled so PowerMenu stays open during screenshot tools (slurp/grim)
    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: root.close()
    }

    // Action definitions for Power Menu
    readonly property var actions: [
        {
            id: "lock",
            icon: "󰌾",
            isUrgent: false,
            exec: function() {
                root.close()
                Quickshell.execDetached(["sh", "-c", "loginctl lock-session || hyprlock || swaylock"])
            }
        },
        {
            id: "logout",
            icon: "󰍃",
            isUrgent: false,
            exec: function() {
                root.close()
                Quickshell.execDetached(["sh", "-c", "hyprctl dispatch exit || loginctl terminate-user \"$USER\""])
            }
        },
        {
            id: "restart",
            icon: "󰑓",
            isUrgent: true,
            exec: function() {
                root.close()
                Quickshell.execDetached(["systemctl", "reboot"])
            }
        },
        {
            id: "shutdown",
            icon: "󰐥",
            isUrgent: true,
            exec: function() {
                root.close()
                Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    ]

    // ─────────────────────────────────────────────────────────────────────────
    // Keyboard Navigation Controller
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.isOpen

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
                return
            }

            // Tab / Shift+Tab cycles between Session -> Themes -> Wallpapers
            if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier) {
                    if (root.currentView === "power") root.toggleWallpaper()
                    else if (root.currentView === "wallpaper") root.toggleTheme()
                    else root.togglePower()
                } else {
                    if (root.currentView === "power") root.toggleTheme()
                    else if (root.currentView === "theme") root.toggleWallpaper()
                    else root.togglePower()
                }
                event.accepted = true
                return
            }

            // Power view navigation
            if (root.currentView === "power") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.powerIndex = (root.powerIndex - 1 + 4) % 4
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.powerIndex = (root.powerIndex + 1) % 4
                    event.accepted = true
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                    var pIdx = event.key - Qt.Key_1
                    root.powerIndex = pIdx
                    root.actions[pIdx].exec()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (root.powerIndex >= 0 && root.powerIndex < root.actions.length) {
                        root.actions[root.powerIndex].exec()
                    }
                    event.accepted = true
                }
            } else if (root.currentView === "theme") {
                // Theme view navigation
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.selectPrevTheme()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.selectNextTheme()
                    event.accepted = true
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    var tIdx = event.key - Qt.Key_1
                    if (tIdx >= 0 && tIdx < root.themesCount) {
                        root.themeIndex = tIdx
                        root.applyTheme(root.themes[tIdx].id)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (root.themeIndex >= 0 && root.themeIndex < root.themesCount) {
                        root.applyTheme(root.themes[root.themeIndex].id)
                    }
                    event.accepted = true
                }
            } else if (root.currentView === "wallpaper") {
                // Wallpaper view navigation
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.selectPrevWallpaper()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.selectNextWallpaper()
                    event.accepted = true
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    var wIdx = event.key - Qt.Key_1
                    if (wIdx >= 0 && wIdx < root.wallpapersCount) {
                        root.wallpaperIndex = wIdx
                        root.applyWallpaper(root.wallpapers[wIdx].path)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (root.wallpaperIndex >= 0 && root.wallpaperIndex < root.wallpapersCount) {
                        root.applyWallpaper(root.wallpapers[root.wallpaperIndex].path)
                    }
                    event.accepted = true
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Unified Bottom Pop-Up Surface (Single Window Box)
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: menuCard

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32

        width: root.targetWidth
        height: root.targetHeight
        radius: 20

        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.width: 0

        // Smooth size morphing when converting between menus while open
        Behavior on width {
            enabled: root.viewTransitionsEnabled
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: root.viewTransitionsEnabled
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        // Pop up from bottom translation & spring physics
        transform: Translate {
            y: (1.0 - root.animProgress) * (menuCard.height + 64)
        }
        opacity: Math.min(1.0, root.animProgress * 1.5)
        scale: 0.94 + 0.06 * Math.max(0, root.animProgress)

        // Block clicks from falling through to backdrop
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ─────────────────────────────────────────────────────────────────
            // Unified Header with View Switcher Tabs & Status
            // ─────────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                // Segmented View Switcher Tabs (Session / Themes / Wallpapers in one box)
                Row {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    // Session Tab
                    Rectangle {
                        width: sessionTabRow.implicitWidth + 14
                        height: 24
                        radius: 12
                        color: (root.currentView === "power")
                            ? Theme.accent
                            : (sessionTabMouse.containsMouse ? Theme.lighter_background : "transparent")

                        Behavior on color {
                            enabled: root.viewTransitionsEnabled
                            ColorAnimation { duration: 150 }
                        }

                        Row {
                            id: sessionTabRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: Icons.power
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 12
                                color: (root.currentView === "power") ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Session"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: (root.currentView === "power") 
                                color: (root.currentView === "power") ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: sessionTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentView !== "power") {
                                    root.currentView = "power"
                                    root.powerIndex = 0
                                }
                            }
                        }
                    }

                    // Themes Tab
                    Rectangle {
                        width: themeTabRow.implicitWidth + 14
                        height: 24
                        radius: 12
                        color: (root.currentView === "theme")
                            ? Theme.accent
                            : (themeTabMouse.containsMouse ? Theme.lighter_background : "transparent")

                        Behavior on color {
                            enabled: root.viewTransitionsEnabled
                            ColorAnimation { duration: Appearance.animDurationNormal }
                        }

                        Row {
                            id: themeTabRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: Icons.palette
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 12
                                color: (root.currentView === "theme") ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Themes"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: (root.currentView === "theme") 
                                color: (root.currentView === "theme") ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: themeTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentView !== "theme") {
                                    if (root.themeService) root.themeService.refresh()
                                    root.currentView = "theme"
                                    root.themeIndex = (root.themeService && root.themeService.middleIndex !== undefined)
                                        ? root.themeService.middleIndex
                                        : Math.floor(root.themesCount / 2)
                                }
                            }
                        }
                    }

                    // Wallpapers Tab
                    Rectangle {
                        width: wallpaperTabRow.implicitWidth + 14
                        height: 24
                        radius: 12
                        color: (root.currentView === "wallpaper")
                            ? Theme.accent
                            : (wallpaperTabMouse.containsMouse ? Theme.lighter_background : "transparent")

                        Behavior on color {
                            enabled: root.viewTransitionsEnabled
                            ColorAnimation { duration: Appearance.animDurationNormal }
                        }

                        Row {
                            id: wallpaperTabRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: Icons.wallpaper
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 12
                                color: (root.currentView === "wallpaper") ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Wallpapers"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: (root.currentView === "wallpaper") 
                                color: (root.currentView === "wallpaper") ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: wallpaperTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentView !== "wallpaper") {
                                    if (root.wallpaperService) root.wallpaperService.refresh()
                                    root.currentView = "wallpaper"
                                    root.wallpaperIndex = (root.wallpaperService && root.wallpaperService.middleIndex !== undefined)
                                        ? root.wallpaperService.middleIndex
                                        : Math.floor(root.wallpapersCount / 2)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right Status Text
                Text {
                    text: {
                        if (root.currentView === "power") {
                            var act = root.actions[root.powerIndex]
                            if (act) {
                                if (act.id === "lock") return "Lock"
                                if (act.id === "logout") return "Log Out"
                                if (act.id === "restart") return "Restart"
                                if (act.id === "shutdown") return "Power Off"
                            }
                            return ""
                        } else if (root.currentView === "theme") {
                            if (root.themeService && root.themeService.isSwitching) {
                                return "󱑊 Switching..."
                            }
                            if (root.themeIndex >= 0 && root.themeIndex < root.themesCount) {
                                var t = root.themes[root.themeIndex]
                                return t.name + (t.isCurrent ? " (Active)" : "")
                            }
                            return ""
                        } else {
                            if (root.wallpaperService && root.wallpaperService.isSwitching) {
                                return "󱑊 Applying..."
                            }
                            return ""
                        }
                    }
                    font.family: Fonts.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: {
                        if (root.currentView === "power") {
                            return (root.actions[root.powerIndex] && root.actions[root.powerIndex].isUrgent)
                                ? Theme.urgent
                                : Theme.accent
                        } else if (root.currentView === "theme") {
                            return (root.themeIndex >= 0 && root.themeIndex < root.themesCount && root.themes[root.themeIndex].accent)
                                ? root.themes[root.themeIndex].accent
                                : Theme.accent
                        } else {
                            return Theme.accent
                        }
                    }
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color {
                        enabled: root.viewTransitionsEnabled
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.withAlpha(Theme.selection, 0.6)
            }

            // ─────────────────────────────────────────────────────────────────
            // Interactive Content View (Crossfades between Power, Themes, Wallpapers)
            // ─────────────────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // VIEW 1: Power Menu (4 Session Action Buttons)
                Item {
                    id: powerViewContainer
                    anchors.fill: parent
                    opacity: (root.currentView === "power") ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        enabled: root.viewTransitionsEnabled
                        NumberAnimation { duration: 180 }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 16

                        Repeater {
                            model: root.actions

                            Item {
                                id: actionBtn
                                required property var modelData
                                required property int index

                                readonly property bool isActive: (root.currentView === "power") && (root.powerIndex === index)

                                width: 64
                                height: 64

                                scale: actionBtn.isActive ? 1.08 : (btnMouse.containsMouse ? 1.03 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.15
                                    }
                                }

                                Rectangle {
                                    id: btnBg
                                    anchors.fill: parent
                                    radius: actionBtn.isActive ? root.activeRadius : root.inactiveRadius

                                    Behavior on radius {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.15
                                        }
                                    }

                                    color: {
                                        if (actionBtn.isActive) {
                                            return actionBtn.modelData.isUrgent ? Theme.urgent : Theme.accent
                                        }
                                        if (btnMouse.containsMouse) {
                                            return Theme.lighter_background
                                        }
                                        return Theme.withAlpha(Theme.darker_background, 0.45)
                                    }

                                    border.color: actionBtn.isActive ? "transparent" : Theme.selection
                                    border.width: actionBtn.isActive ? 0 : 1

                                    Behavior on color { ColorAnimation { duration: 160 } }
                                    Behavior on border.color { ColorAnimation { duration: 160 } }

                                    MouseArea {
                                        id: btnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: {
                                            root.powerIndex = actionBtn.index
                                        }
                                        onClicked: {
                                            actionBtn.modelData.exec()
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: actionBtn.modelData.icon
                                        font.family: Icons.effectiveFont(actionBtn.modelData.icon)
                                        font.pixelSize: 28
                                        color: actionBtn.isActive
                                            ? Theme.darker_background
                                            : (actionBtn.modelData.isUrgent ? Theme.urgent : Theme.foreground)

                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                        }
                    }
                }

                // VIEW 2: Theme Switcher (Active in middle, no active badge on card, no trim)
                Item {
                    id: themeViewContainer
                    anchors.fill: parent
                    opacity: (root.currentView === "theme") ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        enabled: root.viewTransitionsEnabled
                        NumberAnimation { duration: 180 }
                    }

                    ListView {
                        id: themesList
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 12
                        clip: true
                        model: root.themes
                        currentIndex: root.themeIndex
                        boundsBehavior: Flickable.StopAtBounds

                        WheelHandler {
                            target: null
                            onWheel: function(event) {
                                if (event.angleDelta.y !== 0) {
                                    themesList.flick(event.angleDelta.y * 6, 0)
                                }
                            }
                        }

                        delegate: Item {
                            id: cardItem
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: (root.currentView === "theme") && (root.themeIndex === cardItem.index)
                            readonly property bool isCurrentTheme: modelData.isCurrent === true
                            readonly property color themeAccent: modelData.accent ? modelData.accent : Theme.accent

                            width: 196
                            height: 162

                            Rectangle {
                                id: cardBg
                                anchors.fill: parent
                                radius: Appearance.powerMenuRadiusActive

                                color: cardItem.isSelected
                                    ? Theme.withAlpha(Theme.lighter_background, 0.95)
                                    : (cardMouse.containsMouse
                                        ? Theme.withAlpha(Theme.lighter_background, 0.45)
                                        : Theme.withAlpha(Theme.darker_background, 0.45))

                                border.color: cardItem.isSelected
                                    ? cardItem.themeAccent
                                    : (cardItem.isCurrentTheme
                                        ? Theme.withAlpha(Theme.green, 0.6)
                                        : Theme.withAlpha(Theme.selection, 0.6))
                                border.width: cardItem.isSelected ? 2 : 1

                                Behavior on color { ColorAnimation { duration: 160 } }
                                Behavior on border.color { ColorAnimation { duration: 160 } }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: {
                                        root.themeIndex = cardItem.index
                                    }
                                    onClicked: {
                                        root.applyTheme(cardItem.modelData.id)
                                    }
                                }

                                // 1. Wallpaper Thumbnail - Flush with top, left, and right borders
                                Item {
                                    id: imgContainer
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 1
                                    height: 110

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: topMask
                                    }

                                    Image {
                                        id: wallImg
                                        anchors.fill: parent
                                        source: cardItem.modelData.wallpaper ? ("file://" + cardItem.modelData.wallpaper) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        sourceSize: Qt.size(392, 220)
                                    }

                                    // Fallback icon if wallpaper missing
                                    Item {
                                        anchors.fill: parent
                                        visible: !cardItem.modelData.wallpaper || wallImg.status === Image.Error

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰸉"
                                            font.family: Icons.effectiveFont("󰸉")
                                            font.pixelSize: 28
                                            color: Theme.muted
                                        }
                                    }
                                }

                                // Rounded mask matching top-left and top-right of the card
                                Rectangle {
                                    id: topMask
                                    width: imgContainer.width
                                    height: imgContainer.height + 20
                                    radius: Appearance.powerMenuRadiusActive - 1
                                    color: "black"
                                    layer.enabled: true
                                    visible: false
                                }

                                // Hairline separator below thumbnail
                                Rectangle {
                                    anchors.top: imgContainer.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: Theme.withAlpha(Theme.selection, 0.4)
                                }

                                // 2. Theme Name - Cleanly centered below thumbnail (no underline dash)
                                Item {
                                    anchors.top: imgContainer.bottom
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Text {
                                        anchors.centerIn: parent
                                        text: cardItem.modelData.name
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        font.weight: cardItem.isSelected  ? Font.Bold : Font.DemiBold
                                        color: cardItem.isSelected
                                            ? cardItem.themeAccent
                                            : Theme.foreground
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        width: parent.width - 12

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Scroll indicator when themes exceed viewport (more than 5)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(160, parent.width * 0.25)
                        height: 3
                        radius: 1.5
                        color: Theme.withAlpha(Theme.selection, 0.4)
                        visible: themesList.contentWidth > (themesList.width + 4)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                            width: Math.max(20, parent.width * (themesList.width / Math.max(1, themesList.contentWidth)))
                            x: {
                                var scrollableDist = themesList.contentWidth - themesList.width
                                if (scrollableDist <= 0) return 0
                                var trackTravel = parent.width - width
                                return Math.max(0, Math.min(trackTravel, (themesList.contentX / scrollableDist) * trackTravel))
                            }
                        }
                    }
                }

                // VIEW 3: Wallpaper Switcher (Fetches from ~/themes/current dir, active in middle, no trim)
                Item {
                    id: wallpaperViewContainer
                    anchors.fill: parent
                    opacity: (root.currentView === "wallpaper") ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        enabled: root.viewTransitionsEnabled
                        NumberAnimation { duration: 180 }
                    }

                    ListView {
                        id: wallpapersList
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 12
                        clip: true
                        model: root.wallpapers
                        currentIndex: root.wallpaperIndex
                        boundsBehavior: Flickable.StopAtBounds

                        WheelHandler {
                            target: null
                            onWheel: function(event) {
                                if (event.angleDelta.y !== 0) {
                                    wallpapersList.flick(event.angleDelta.y * 6, 0)
                                }
                            }
                        }

                        delegate: Item {
                            id: wallCardItem
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: (root.currentView === "wallpaper") && (root.wallpaperIndex === wallCardItem.index)
                            readonly property bool isActiveWall: modelData.isActive === true

                            width: 196
                            height: 110

                            // 1. Card Background
                            Rectangle {
                                id: wallCardBg
                                anchors.fill: parent
                                radius: Appearance.powerMenuRadiusActive
                                color: wallCardItem.isSelected
                                    ? Theme.withAlpha(Theme.lighter_background, 0.95)
                                    : (wallCardMouse.containsMouse
                                        ? Theme.withAlpha(Theme.lighter_background, 0.45)
                                        : Theme.withAlpha(Theme.darker_background, 0.45))
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            // 2. Direct Mask for Rounded Wallpaper Corners
                            Rectangle {
                                id: wallMask
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Appearance.powerMenuRadiusActive - 1
                                color: "black"
                                layer.enabled: true
                                visible: false
                            }

                            // 3. Wallpaper Image Thumbnail (Masked to 16:9 widescreen ratio)
                            Image {
                                id: previewImg
                                anchors.fill: parent
                                anchors.margins: 1
                                source: wallCardItem.modelData.path ? ("file://" + wallCardItem.modelData.path) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                mipmap: true
                                sourceSize: Qt.size(392, 220)

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: wallMask
                                }
                            }

                            // Fallback icon if image loading error
                            Item {
                                anchors.fill: parent
                                visible: !wallCardItem.modelData.path || previewImg.status === Image.Error

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰸉"
                                    font.family: Icons.effectiveFont("󰸉")
                                    font.pixelSize: 32
                                    color: Theme.muted
                                }
                            }

                            // 4. Border Overlay rendered on top so corner anti-aliasing is crisp
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.powerMenuRadiusActive
                                color: "transparent"
                                border.color: wallCardItem.isSelected
                                    ? Theme.accent
                                    : (wallCardItem.isActiveWall
                                        ? Theme.withAlpha(Theme.green, 0.6)
                                        : Theme.withAlpha(Theme.selection, 0.6))
                                border.width: wallCardItem.isSelected ? 2 : 1
                                Behavior on border.color { ColorAnimation { duration: 160 } }
                            }

                            // 5. Interactive Mouse Area
                            MouseArea {
                                id: wallCardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onEntered: {
                                    root.wallpaperIndex = wallCardItem.index
                                }
                                onClicked: {
                                    root.applyWallpaper(wallCardItem.modelData.path)
                                }
                            }
                        }
                    }

                    // Scroll indicator when wallpapers exceed viewport (more than 5)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(160, parent.width * 0.25)
                        height: 3
                        radius: 1.5
                        color: Theme.withAlpha(Theme.selection, 0.4)
                        visible: wallpapersList.contentWidth > (wallpapersList.width + 4)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                            width: Math.max(20, parent.width * (wallpapersList.width / Math.max(1, wallpapersList.contentWidth)))
                            x: {
                                var scrollableDist = wallpapersList.contentWidth - wallpapersList.width
                                if (scrollableDist <= 0) return 0
                                var trackTravel = parent.width - width
                                return Math.max(0, Math.min(trackTravel, (wallpapersList.contentX / scrollableDist) * trackTravel))
                            }
                        }
                    }
                }
            }
        }
    }
}

