import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property Item anchorItem
    property var anchorWindow: null
    property MediaController controller: null
    property AudioService audioService: null

    property bool open: false
    property int contentWidth: Appearance.mediaIslandWidth
    property int contentHeight: Appearance.mediaIslandHeight
    property double lastClearedTime: 0

    // High-resolution App icon mapping for whichever app is currently playing audio
    readonly property string appIconSource: {
        if (!root.controller || !root.controller.activePlayer) return ""
        var p = root.controller.activePlayer
        var entry = (p.desktopEntry || "").toLowerCase()
        var ident = (p.identity || "").toLowerCase()
        var dbus = (p.dbusName || "").toLowerCase()
        var all = entry + " " + ident + " " + dbus

        // 1. Try direct DesktopEntries lookup
        if (p.desktopEntry) {
            var de = DesktopEntries.byId(p.desktopEntry)
            if (de && de.icon) {
                var p1 = Quickshell.iconPath(de.icon, true)
                if (p1 && p1 !== "") return p1
            }
        }
        var deGuess = DesktopEntries.heuristicLookup(p.desktopEntry || p.identity || "")
        if (deGuess && deGuess.icon) {
            var p2 = Quickshell.iconPath(deGuess.icon, true)
            if (p2 && p2 !== "") return p2
        }

        // 2. Comprehensive player-specific high-res icon search
        var candidates = []
        if (all.indexOf("spotify") !== -1) candidates = ["spotify-launcher", "spotify", "spotify-client"]
        else if (all.indexOf("brave") !== -1) candidates = ["brave-origin", "brave-browser", "brave", "brave-bin"]
        else if (all.indexOf("zen") !== -1) candidates = ["zen-browser", "zen"]
        else if (all.indexOf("firefox") !== -1) candidates = ["firefox", "firefox-developer-edition", "firefox-nightly"]
        else if (all.indexOf("chromium") !== -1) candidates = ["chromium", "chromium-browser"]
        else if (all.indexOf("chrome") !== -1) candidates = ["google-chrome", "google-chrome-stable", "chrome"]
        else if (all.indexOf("vlc") !== -1) candidates = ["vlc"]
        else if (all.indexOf("mpv") !== -1) candidates = ["mpv"]
        else if (all.indexOf("cider") !== -1) candidates = ["cider"]
        else if (all.indexOf("amberol") !== -1) candidates = ["io.bassi.Amberol", "amberol"]
        else if (all.indexOf("youtube") !== -1) candidates = ["com.github.th_ch.youtube_music", "youtube-music", "youtubemusic"]
        else if (all.indexOf("discord") !== -1) candidates = ["discord"]
        else if (all.indexOf("audacious") !== -1) candidates = ["audacious"]
        else if (all.indexOf("rhythmbox") !== -1) candidates = ["rhythmbox"]
        else if (all.indexOf("elisa") !== -1) candidates = ["elisa"]
        else if (p.desktopEntry) candidates = [p.desktopEntry]

        for (var i = 0; i < candidates.length; i++) {
            var path = Quickshell.iconPath(candidates[i], true)
            if (path && path !== "") return path
        }
        return ""
    }

    readonly property string appGlyph: {
        if (!root.controller || !root.controller.activePlayer) return "󰝚"
        var p = root.controller.activePlayer
        var s = ((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "")).toLowerCase()
        if (s.indexOf("spotify") !== -1) return "󰓋"
        if (s.indexOf("brave") !== -1) return "󰖠"
        if (s.indexOf("firefox") !== -1) return "󰈹"
        if (s.indexOf("chrome") !== -1 || s.indexOf("chromium") !== -1) return "󰊹"
        if (s.indexOf("youtube") !== -1) return "󰗃"
        if (s.indexOf("vlc") !== -1) return "󰖀"
        if (s.indexOf("mpv") !== -1) return "󰕼"
        return "󰝚"
    }

    readonly property color appGlyphColor: {
        if (!root.controller || !root.controller.activePlayer) return Theme.foreground
        var p = root.controller.activePlayer
        var s = ((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "")).toLowerCase()
        if (s.indexOf("spotify") !== -1) return Theme.green
        if (s.indexOf("brave") !== -1) return Theme.orange
        if (s.indexOf("firefox") !== -1) return Theme.bright_yellow
        if (s.indexOf("chrome") !== -1 || s.indexOf("chromium") !== -1) return Theme.blue
        if (s.indexOf("youtube") !== -1) return Theme.red
        if (s.indexOf("vlc") !== -1) return Theme.orange
        return Theme.foreground
    }

    readonly property color appBadgeBg: Theme.dark_background

    // Interactive scrubbing state
    property bool isDraggingSeek: false
    property real dragProgress: 0.0

    // Bouncy morph transition (State A -> State B)
    property real animProgress: 0.0

    NumberAnimation {
        id: openAnim
        target: root
        property: "animProgress"
        from: root.animProgress
        to: 1.0
        duration: 300
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "animProgress"
        from: root.animProgress
        to: 0.0
        duration: 200
        easing.type: Easing.InCubic
    }

    Timer {
        id: grabDelayTimer
        interval: 150
        onTriggered: {
            if (root.open) {
                focusGrab.active = true
            }
        }
    }

    onOpenChanged: {
        if (root.open) {
            closeAnim.stop()
            openAnim.restart()
            grabDelayTimer.restart()
        } else {
            grabDelayTimer.stop()
            focusGrab.active = false
            openAnim.stop()
            closeAnim.restart()
        }
    }

    function toggle() {
        if (Date.now() - root.lastClearedTime < 250) {
            root.open = false
            return
        }
        root.open = !root.open
    }

    function getAnchorWindow() {
        if (root.anchorWindow) return root.anchorWindow
        if (root.anchorItem && root.anchorItem.window) return root.anchorItem.window
        if (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) return root.anchorItem.QsWindow.window
        return null
    }

    visible: open || animProgress > 0.001
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    screen: (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window.screen : null

    WlrLayershell.namespace: "quickshell-surface"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [root]
        onCleared: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    // Dismiss when clicking outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    readonly property real cardX: {
        var _ = root.open
        if (!root.anchorItem) return 10

        var win = (root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window : null
        var screenW = (win && win.screen) ? win.screen.width : root.width

        var barScreenX = 0
        if (win) {
            if (win.anchors && win.anchors.left) {
                barScreenX = (win.margins && win.margins.left) ? win.margins.left : 0
            } else {
                barScreenX = Math.round((screenW - win.width) / 2)
            }
        }

        var pt = root.anchorItem.mapToItem(null, 0, 0)
        var margin = 10
        var itemScreenX = barScreenX + pt.x
        return Math.max(margin, Math.min(itemScreenX, screenW - root.contentWidth - margin))
    }

    readonly property real cardY: {
        var _ = root.open
        if (!root.anchorItem) return Theme.barHeight + 6

        var win = (root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window : null
        var barScreenY = 0
        if (win && win.margins && win.margins.top) {
            barScreenY = win.margins.top
        }

        var pt = root.anchorItem.mapToItem(null, 0, 0)
        return Math.max(Theme.barHeight + 6, barScreenY + pt.y + root.anchorItem.height + 6)
    }

    // Outer Frosted Container (Pixel-perfect ColorOS / Dynamic Island Live Alert card)
    Rectangle {
        id: cardRect
        x: Math.round(root.cardX)
        y: Math.round(root.cardY)
        width: root.contentWidth
        height: root.contentHeight
        radius: Appearance.mediaIslandRadius
        color: Theme.withAlpha(Theme.dark_background, Theme.baseOpacity)
        border.color: "transparent"
        border.width: 0

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) { mouse.accepted = false }
        }

        transformOrigin: Item.TopLeft
        scale: 0.32 + 0.68 * root.animProgress
        opacity: Math.min(1.0, root.animProgress * 1.8)

        // Main Horizontal Layout: Left = Album Art Thumbnail, Right = Media Column
        Row {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            opacity: Math.max(0.0, Math.min(1.0, (root.animProgress - 0.15) * 1.8))

            // 1. Album Artwork Thumbnail (Strictly Rounded Corners using MultiEffect Mask)
            Item {
                id: albumCoverBox
                width: 82
                height: 82
                anchors.top: parent.top

                // Mask defining sharp rounded corners (Appearance.radiusMedium: 8px)
                Rectangle {
                    id: albumCoverMask
                    anchors.fill: parent
                    radius: Appearance.radiusMedium
                    color: "black"
                    layer.enabled: true
                    visible: false
                }

                // Underlying fallback when no artwork is available
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.radiusMedium
                    color: Theme.dark_background
                    border.color: "transparent"
                    border.width: 0
                    visible: !coverImg.visible

                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.family: Icons.effectiveFont("󰝚")
                        font.pixelSize: Fonts.scale(32)
                        color: Theme.muted
                    }
                }

                // Album Artwork with anti-aliased rounded corner mask
                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: root.controller ? root.controller.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: albumCoverMask
                    }
                }

                // Razor-crisp outline over rounded album art (borderless)
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.radiusMedium
                    color: "transparent"
                    border.color: "transparent"
                    border.width: 0
                    z: 10
                }
            }

            // 2. Right Side Column: Title/Artist + App Icon, Progress groove, Playback Controls
            Column {
                id: rightMediaCol
                width: parent.width - albumCoverBox.width - parent.spacing
                anchors.top: parent.top
                spacing: 8

                // --- TOP ROW: Track Info + App Icon (in which audio is playing) ---
                Row {
                    width: parent.width
                    spacing: 8

                    Column {
                        width: parent.width - appIconBox.width - parent.spacing
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: root.controller && root.controller.title ? root.controller.title : "No Media"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeMedium
                            font.weight: Fonts.weightBold
                            color: Theme.foreground
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            width: parent.width
                            text: root.controller && root.controller.artist ? root.controller.artist : "Unknown Artist"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            color: Theme.muted
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // App Icon in which audio is playing (Top Right)
                    Item {
                        id: appIconBox
                        width: 30
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter

                        // Squircle container with native clipping
                        Rectangle {
                            id: appIconBg
                            anchors.fill: parent
                            radius: 6
                            clip: true
                            color: root.appBadgeBg
                            border.color: "transparent"
                            border.width: 0

                            // High-res desktop app icon (anti-aliased, mipmapped)
                            Image {
                                id: appIconImg
                                anchors.fill: parent
                                anchors.margins: 4
                                source: root.appIconSource
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 64
                                sourceSize.height: 64
                                mipmap: true
                                smooth: true
                                asynchronous: true
                                visible: root.appIconSource !== "" && status === Image.Ready
                            }

                            // Fallback branded glyph if icon image is not found
                            Text {
                                anchors.centerIn: parent
                                text: root.appGlyph
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(18)
                                color: root.appGlyphColor
                                visible: !appIconImg.visible
                            }
                        }
                    }
                }

                // --- MIDDLE ROW: Progress Groove Line & Timestamps ---
                Column {
                    width: parent.width
                    spacing: 3

                    Item {
                        id: progressGrooveArea
                        width: parent.width
                        height: 12

                        readonly property real curProgress: root.isDraggingSeek ? root.dragProgress : (root.controller ? root.controller.progress : 0)

                        // Groove line background
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 3.5
                            radius: 1.75
                            color: Theme.selection
                        }

                        // Played active progress
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            width: Math.max(0, Math.min(parent.width, parent.width * progressGrooveArea.curProgress))
                            height: 3.5
                            radius: 1.75
                            color: Theme.accent
                        }

                        // Playback Pill / Dot Head
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, parent.width * progressGrooveArea.curProgress - width / 2))
                            width: 14
                            height: 6
                            radius: 3
                            color: Theme.bright_foreground
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function updateFromMouse(mouseX) {
                                var pct = Math.max(0.0, Math.min(1.0, mouseX / width))
                                root.dragProgress = pct
                            }

                            onPressed: function(mouse) {
                                root.isDraggingSeek = true
                                updateFromMouse(mouse.x)
                            }

                            onPositionChanged: function(mouse) {
                                if (root.isDraggingSeek) {
                                    updateFromMouse(mouse.x)
                                }
                            }

                            onReleased: function(mouse) {
                                if (root.isDraggingSeek) {
                                    updateFromMouse(mouse.x)
                                    if (root.controller && root.controller.length > 0) {
                                        root.controller.seekTo(root.dragProgress * root.controller.length)
                                    }
                                    root.isDraggingSeek = false
                                }
                            }
                        }
                    }

                    // Elapsed & Total Timestamps
                    Item {
                        width: parent.width
                        height: 12

                        Text {
                            anchors.left: parent.left
                            text: root.controller ? root.controller.formatTime(root.isDraggingSeek ? (root.dragProgress * root.controller.length) : root.controller.position) : "00:00"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(10)
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.controller ? root.controller.formatTime(root.controller.length) : "00:00"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(10)
                            color: Theme.muted
                        }
                    }
                }

                // --- BOTTOM ROW: Previous | Play/Pause | Next (Centered matching reference image) ---
                Item {
                    width: parent.width
                    height: 30

                    Row {
                        anchors.centerIn: parent
                        spacing: 48

                        // 1. Previous Button
                        Item {
                            width: 28
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.family: Icons.effectiveFont("󰒮")
                                font.pixelSize: Fonts.scale(32)
                                color: root.controller && root.controller.canGoPrevious ? (prevMouse.containsMouse ? Theme.bright_foreground : Theme.foreground) : Theme.muted
                                scale: prevMouse.pressed ? 0.90 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.controller) root.controller.previous()
                            }
                        }

                        // 2. Central Play / Pause Toggle
                        Item {
                            width: 32
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: root.controller && root.controller.isPlaying ? "󰏤" : "󰐊"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(34)
                                color: playMouse.containsMouse ? Theme.bright_foreground : Theme.foreground
                                scale: playMouse.pressed ? 0.88 : 1.0
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.controller) root.controller.togglePlay()
                            }
                        }

                        // 3. Next Button
                        Item {
                            width: 28
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.family: Icons.effectiveFont("󰒭")
                                font.pixelSize: Fonts.scale(32)
                                color: root.controller && root.controller.canGoNext ? (nextMouse.containsMouse ? Theme.bright_foreground : Theme.foreground) : Theme.muted
                                scale: nextMouse.pressed ? 0.90 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.controller) root.controller.next()
                            }
                        }
                    }
                }
            }
        }
    }
}
