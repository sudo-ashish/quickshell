import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../services"

PopupWindow {
    id: root

    required property Item anchorItem
    property MediaController controller: null
    property AudioService audioService: null

    property bool open: false
    property int contentWidth: Appearance.mediaPopupWidth
    property int contentHeight: Appearance.mediaPopupHeight
    property double lastClearedTime: 0

    // Interactive scrubbing state
    property bool isDraggingSeek: false
    property real dragProgress: 0.0

    // Live travelling wave phase animation while playing
    property real wavePhase: 0.0

    NumberAnimation {
        id: waveAnim
        target: root
        property: "wavePhase"
        from: 0.0
        to: Math.PI * 2
        duration: 2200
        loops: Animation.Infinite
        running: (root.open || root.animProgress > 0.001) && (root.controller ? root.controller.isPlaying : false)
    }

    onWavePhaseChanged: if (root.open || root.animProgress > 0.001) waveCanvas.requestPaint()

    // Bouncy morph/expand animation progress between mediapill and mediapopup (bidirectional)
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

    // Sync seek bar via 500ms timer active only during playback while open
    Timer {
        id: seekSyncTimer
        interval: 500
        repeat: true
        running: root.open && (root.controller ? root.controller.isPlaying : false)
        onTriggered: {
            if (root.controller) waveCanvas.requestPaint()
        }
    }

    onOpenChanged: {
        if (root.open) {
            closeAnim.stop()
            openAnim.restart()
            waveCanvas.requestPaint()
        } else {
            openAnim.stop()
            closeAnim.restart()
        }
    }

    Connections {
        target: root.controller
        function onIsPlayingChanged() {
            if (root.open || root.animProgress > 0.001) waveCanvas.requestPaint()
        }
        function onProgressChanged() {
            if ((root.open || root.animProgress > 0.001) && !root.isDraggingSeek) waveCanvas.requestPaint()
        }
    }

    // App icon mapping for active media player (e.g. Brave, Spotify, Firefox, VLC, Chrome, mpv)
    readonly property string appIcon: {
        var raw = ""
        if (root.controller && root.controller.activePlayer) {
            var p = root.controller.activePlayer
            raw = (p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "")
        } else if (root.controller) {
            raw = (root.controller.identity || "")
        }
        var s = raw.toLowerCase()
        if (s.indexOf("spotify") !== -1) return "󰓋"
        if (s.indexOf("brave") !== -1) return "󰖠"
        if (s.indexOf("firefox") !== -1) return "󰈹"
        if (s.indexOf("chrome") !== -1 || s.indexOf("chromium") !== -1) return "󰊹"
        if (s.indexOf("youtube") !== -1) return "󰗃"
        if (s.indexOf("vlc") !== -1) return "󰖀"
        if (s.indexOf("mpv") !== -1) return "󰕼"
        if (s.indexOf("apple") !== -1 || s.indexOf("cider") !== -1) return "󰀵"
        return "󰝚"
    }

    readonly property string audioOutputName: {
        if (!audioService) return "Alto-falante do telefone"
        if (audioService.volumeName && audioService.volumeName !== "") return audioService.volumeName
        if (audioService.sink && audioService.sink.name) return audioService.sink.name
        return "Alto-falante do telefone"
    }

    function toggle() {
        if (Date.now() - root.lastClearedTime < 250) {
            root.open = false
            return
        }
        root.open = !root.open
    }

    function getAnchorWindow() {
        if (!root.anchorItem) return null
        if (root.anchorItem.window) return root.anchorItem.window
        if (root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) return root.anchorItem.QsWindow.window
        return null
    }

    visible: open || animProgress > 0.001
    implicitWidth: contentWidth
    implicitHeight: contentHeight
    color: "transparent"

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    anchor {
        id: popAnchor
        window: root.getAnchorWindow()
        rect.width: 1
        rect.height: 1
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right

        onAnchoring: {
            if (!root.anchorItem) return
            var win = root.getAnchorWindow()
            if (!win) return

            // Align menu's left edge with the pill's left edge, extending to the right
            var localX = 0
            var localY = root.anchorItem.height + 6
            var pt = win.contentItem.mapFromItem(root.anchorItem, localX, localY)

            // Clamp within screen margins
            var margin = 10
            var clampedX = Math.max(margin, Math.min(pt.x, win.width - root.implicitWidth - margin))
            popAnchor.rect.x = Math.round(clampedX)
            popAnchor.rect.y = Math.round(pt.y)
        }
    }

    // Direct Rectangle mask used by MultiEffect to strictly round the content inside the card
    Rectangle {
        id: cardMask
        width: innerContent.width
        height: innerContent.height
        radius: Math.max(10, cardRect.radius - 2)
        color: "black"
        layer.enabled: true
        visible: false
    }

    // Outer Card Container matching Samsung One UI 7 reference image
    Rectangle {
        id: cardRect
        anchors.fill: parent
        radius: Math.round(13 + (24 - 13) * Math.min(1.0, root.animProgress))
        color: Theme.dark_background

        transformOrigin: Item.TopLeft
        scale: 0.30 + 0.70 * root.animProgress
        opacity: Math.min(1.0, root.animProgress * 1.8)
        y: -8 * (1.0 - Math.min(1.0, root.animProgress))

        // Inner masked container for album art and gradients (inset by 2px so color NEVER bleeds outside the border)
        Item {
            id: innerContent
            anchors.fill: parent
            anchors.margins: 2

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }

            // 1. Full-bleed Album Artwork Background
            Image {
                id: fullBleedArt
                anchors.fill: parent
                source: root.controller ? root.controller.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            // Fallback dark gradient when no artwork
            Rectangle {
                anchors.fill: parent
                radius: Math.max(10, cardRect.radius - 2)
                visible: !fullBleedArt.visible
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.selection }
                    GradientStop { position: 1.0; color: Theme.darker_background }
                }
            }

            // 2. Translucent dark overlay so text & controls pop with high contrast
            Rectangle {
                anchors.fill: parent
                radius: Math.max(10, cardRect.radius - 2)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.dark_background }
                    GradientStop { position: 0.35; color: Theme.background }
                    GradientStop { position: 0.70; color: Theme.dark_background }
                    GradientStop { position: 1.0; color: Theme.darker_background }
                }
            }
        }

        // Dedicated crisp border overlay
        Rectangle {
            anchors.fill: parent
            radius: cardRect.radius
            color: "transparent"
            border.color: "transparent"
            border.width: 0
            z: 99
        }

        // 3. Card Content Layout (fades in smoothly as card expands, reverses on collapse)
        Column {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 14
            anchors.bottomMargin: 12
            spacing: 6
            opacity: Math.max(0.0, Math.min(1.0, (root.animProgress - 0.12) * 1.6))

            // --- HEADER: App Icon & Output Device Badge ---
            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: root.appIcon
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Fonts.scale(14)
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.audioOutputName
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeSmall
                    font.weight: Fonts.weightMedium
                    color: Theme.bright_foreground
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(parent.width - 28, implicitWidth)
                }
            }

            // --- TITLE & ARTIST ---
            Column {
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: root.controller ? root.controller.title : "No Media"
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.scale(17)
                    font.weight: Fonts.weightBold
                    color: Theme.bright_foreground
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: root.controller ? root.controller.artist : "Unknown Artist"
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeRegular
                    color: Theme.foreground
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Spacer
            Item {
                width: parent.width
                height: 2
            }

            // --- WAVY AUDIO PROGRESS BAR WITH ANIMATED SQUIGGLE ---
            Column {
                width: parent.width
                spacing: 3

                // Wavy Canvas Seeker
                Item {
                    id: waveSeekerArea
                    width: parent.width
                    height: 24

                    readonly property real curProgress: root.isDraggingSeek ? root.dragProgress : (root.controller ? root.controller.progress : 0)

                    onCurProgressChanged: waveCanvas.requestPaint()

                    Canvas {
                        id: waveCanvas
                        anchors.fill: parent

                        function drawRoundedRect(ctx, x, y, w, h, r) {
                            if (w < 2 * r) r = w / 2
                            if (h < 2 * r) r = h / 2
                            ctx.beginPath()
                            ctx.moveTo(x + r, y)
                            ctx.arcTo(x + w, y, x + w, y + h, r)
                            ctx.arcTo(x + w, y + h, x, y + h, r)
                            ctx.arcTo(x, y + h, x, y, r)
                            ctx.arcTo(x, y, x + w, y, r)
                            ctx.closePath()
                            ctx.fill()
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var cy = height / 2 + 3
                            var progress = Math.max(0.0, Math.min(1.0, waveSeekerArea.curProgress))
                            var playedW = width * progress
                            var baseH = 5

                            // 1. Unplayed straight track
                            ctx.fillStyle = Theme.muted
                            drawRoundedRect(ctx, 0, cy - baseH/2, width, baseH, baseH/2)

                            // 2. Played wavy track (animated ripple while playing matching reference image)
                            if (playedW > 0) {
                                ctx.fillStyle = Theme.accent

                                if (playedW < 14) {
                                    drawRoundedRect(ctx, 0, cy - baseH/2, playedW, baseH, baseH/2)
                                } else {
                                    ctx.beginPath()
                                    // Left rounded cap
                                    ctx.arc(baseH/2, cy, baseH/2, Math.PI * 0.5, Math.PI * 1.5, false)

                                    var wavelength = 55
                                    var maxAmp = 10.0
                                    var step = 2

                                    for (var x = baseH/2; x <= playedW; x += step) {
                                        var normX = x / playedW
                                        var taper = Math.sin(normX * Math.PI)
                                        var angle = (x / wavelength) * 2 * Math.PI - (root.controller && root.controller.isPlaying ? root.wavePhase : 0)
                                        var wave = Math.sin(angle) * 0.5 + 0.5
                                        var waveY = cy - baseH/2 - (wave * maxAmp * Math.pow(taper, 0.65))
                                        ctx.lineTo(x, waveY)
                                    }

                                    ctx.lineTo(playedW, cy + baseH/2)
                                    ctx.lineTo(baseH/2, cy + baseH/2)
                                    ctx.closePath()
                                    ctx.fill()
                                }

                                // 3. White circular thumb
                                ctx.fillStyle = Theme.bright_foreground
                                ctx.beginPath()
                                var thumbX = Math.max(baseH/2, Math.min(width - baseH/2, playedW))
                                ctx.arc(thumbX, cy, 6.5, 0, Math.PI * 2)
                                ctx.fill()
                            }
                        }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateFromMouse(mouseX) {
                            var pct = Math.max(0.0, Math.min(1.0, mouseX / width))
                            root.dragProgress = pct
                            waveCanvas.requestPaint()
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
                                waveCanvas.requestPaint()
                            }
                        }
                    }
                }

                // Time counters below seeker: elapsed on left, remaining/total on right
                Item {
                    width: parent.width
                    height: 12

                    Text {
                        anchors.left: parent.left
                        text: root.controller ? root.controller.formatTime(root.isDraggingSeek ? (root.dragProgress * root.controller.length) : root.controller.position) : "00:00"
                        font.family: Fonts.monoFont
                        font.pixelSize: Fonts.scale(11)
                        color: Theme.muted
                    }

                    Text {
                        anchors.right: parent.right
                        text: root.controller ? root.controller.formatTime(root.controller.length) : "00:00"
                        font.family: Fonts.monoFont
                        font.pixelSize: Fonts.scale(11)
                        color: Theme.muted
                    }
                }
            }

            // --- CONTROLS ROW: Shuffle | Prev | Play/Pause | Next | Repeat ---
            Row {
                width: parent.width
                height: 32
                spacing: (width - (28 + 30 + 34 + 30 + 28)) / 4

                // 1. Shuffle Button
                Item {
                    width: 28
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒝"
                        font.family: Icons.effectiveFont("󰒝")
                        font.pixelSize: Fonts.scale(20)
                        color: root.controller && root.controller.shuffle ? Theme.accent : (shuffMouse.containsMouse ? Theme.bright_foreground : Theme.foreground)
                        scale: shuffMouse.pressed ? 0.90 : 1.0

                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: shuffMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.controller) root.controller.toggleShuffle()
                    }
                }

                // 2. Previous Button
                Item {
                    width: 30
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: Icons.effectiveFont("󰒮")
                        font.pixelSize: Fonts.scale(22)
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

                // 3. Central Play / Pause (Clean white glyph)
                Item {
                    width: 34
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.controller && root.controller.isPlaying ? "󰏤" : "󰐊"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.scale(26)
                        color: playMouse.containsMouse ? Theme.bright_foreground : Theme.foreground
                        scale: playMouse.pressed ? 0.88 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                        }
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.controller) root.controller.togglePlay()
                    }
                }

                // 4. Next Button
                Item {
                    width: 30
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: Icons.effectiveFont("󰒭")
                        font.pixelSize: Fonts.scale(22)
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

                // 5. Repeat / Loop Button
                Item {
                    width: 28
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property int loopState: root.controller ? root.controller.loopState : 0
                    readonly property bool isLoopActive: loopState !== 0

                    Text {
                        anchors.centerIn: parent
                        text: parent.loopState === 2 ? "󰑘" : "󰑖"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.scale(20)
                        color: parent.isLoopActive ? Theme.accent : (loopMouse.containsMouse ? Theme.bright_foreground : Theme.foreground)
                        scale: loopMouse.pressed ? 0.90 : 1.0

                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: loopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.controller) root.controller.cycleLoop()
                    }
                }
            }
        }
    }
}
