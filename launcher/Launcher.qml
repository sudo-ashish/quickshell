import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "LauncherModel.js" as LauncherModel

PanelWindow {
    id: root

    property bool isOpen: false
    property int currentMode: 0 // 0: Apps, 1: Run, 2: Files, 3: Windows
    property string searchText: ""
    property var allApps: []
    property var cachedBinaries: []
    property var cachedFiles: ""
    property var cachedWindows: "[]"
    property var currentItems: []

    function open(initialText) {
        root.isOpen = true
        root.currentMode = 0 // Default to Apps mode
        root.refreshCurrentMode()
        if (typeof initialText === "string" && initialText.length > 0) {
            searchInput.text = initialText
        } else {
            searchInput.text = ""
        }
        listView.currentIndex = 0
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function close() {
        root.isOpen = false
        searchInput.text = ""
        root.currentMode = 0
        listView.currentIndex = 0
    }

    function toggle(initialText) {
        if (root.isOpen) {
            root.close()
        } else {
            root.open(initialText)
        }
    }

    function setMode(index) {
        if (index >= 0 && index <= 3) {
            root.currentMode = index
            root.refreshCurrentMode()
            listView.currentIndex = 0
            Qt.callLater(function() {
                searchInput.forceActiveFocus()
            })
        }
    }

    function cycleMode(forward) {
        if (forward) {
            root.setMode((root.currentMode + 1) % 4)
        } else {
            root.setMode((root.currentMode + 3) % 4)
        }
    }

    function refreshCurrentMode() {
        if (root.currentMode === 0) {
            // Apps
            root.allApps = DesktopEntries.applications.values || []
            root.updateFilteredItems()
        } else if (root.currentMode === 1) {
            // Run commands
            if (root.cachedBinaries.length === 0 && !binScanProc.running) {
                binScanProc.running = true
            } else {
                root.updateFilteredItems()
            }
        } else if (root.currentMode === 2) {
            // Files
            if (!fileScanProc.running) {
                fileScanProc.running = true
            } else {
                root.updateFilteredItems()
            }
        } else if (root.currentMode === 3) {
            // Windows
            if (!windowsProc.running) {
                windowsProc.running = true
            } else {
                root.updateFilteredItems()
            }
        }
    }

    function updateFilteredItems() {
        var q = searchInput.text.trim()
        if (root.currentMode === 0) {
            root.currentItems = LauncherModel.filterApps(root.allApps, q)
        } else if (root.currentMode === 1) {
            root.currentItems = LauncherModel.filterCommands(root.cachedBinaries, q)
        } else if (root.currentMode === 2) {
            root.currentItems = LauncherModel.parseFiles(root.cachedFiles, q)
        } else if (root.currentMode === 3) {
            root.currentItems = LauncherModel.parseWindows(root.cachedWindows, q)
        }
        if (listView.currentIndex >= root.currentItems.length) {
            listView.currentIndex = 0
        }
    }

    function executeCurrentItem() {
        if (!root.currentItems || root.currentItems.length === 0) {
            // If in Run mode with typed text, execute it
            if (root.currentMode === 1 && searchInput.text.trim().length > 0) {
                Quickshell.execDetached(["bash", "-c", searchInput.text.trim()])
                root.close()
            }
            return
        }

        var item = root.currentItems[listView.currentIndex]
        if (!item) return

        if (item.type === "app") {
            try {
                if (item.entry && item.entry.runInTerminal) {
                    Quickshell.execDetached(["gtk-launch", item.id])
                } else if (item.entry && item.entry.execute) {
                    item.entry.execute()
                } else {
                    Quickshell.execDetached(["gtk-launch", item.id])
                }
            } catch (e) {
                Quickshell.execDetached(["gtk-launch", item.id])
            }
        } else if (item.type === "command") {
            Quickshell.execDetached(["bash", "-c", item.cmd])
        } else if (item.type === "file") {
            Quickshell.execDetached(["xdg-open", item.path])
        } else if (item.type === "window") {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + item.address])
        }

        root.close()
    }

    // Window Setup
    visible: root.isOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Bind screen dynamically to focused Hyprland monitor
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

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    onIsOpenChanged: {
        if (root.isOpen) {
            Qt.callLater(function() {
                searchInput.forceActiveFocus()
            })
        }
    }

    // IPC interface for toggling or controlling launcher
    IpcHandler {
        target: "launcher"
        function open(): void { root.open("") }
        function search(query: string): void { root.open(query) }
        function close(): void { root.close() }
        function toggle(): void { root.toggle("") }
        function setMode(mode: string): void {
            if (mode === "apps") root.setMode(0)
            else if (mode === "run") root.setMode(1)
            else if (mode === "files") root.setMode(2)
            else if (mode === "windows") root.setMode(3)
        }
    }

    // Backdrop Scrim (Tier 2 alpha <= 0.35 -> will NOT blur)
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)
        opacity: root.isOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    // Click outside card to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: root.close()
    }

    // Process for scanning executables in PATH for Run mode
    property Process binScanProc: Process {
        id: binScanProc
        command: ["bash", "-c", "echo \"$PATH\" | tr ':' '\n' | while read -r d; do [ -d \"$d\" ] && find \"$d\" -maxdepth 1 -executable -type f -printf '%f\n' 2>/dev/null; done | sort -u | head -n 400"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = text.trim()
                if (raw) {
                    root.cachedBinaries = raw.split("\n")
                }
                if (root.currentMode === 1) {
                    root.updateFilteredItems()
                }
            }
        }
    }

    // Process for scanning files in Files mode
    property Process fileScanProc: Process {
        id: fileScanProc
        command: ["bash", "-c", "find \"$HOME\" -maxdepth 2 -not -path '*/.*' -printf '%f\t%p\t%y\n' 2>/dev/null | head -n 300"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.cachedFiles = text.trim()
                if (root.currentMode === 2) {
                    root.updateFilteredItems()
                }
            }
        }
    }

    // Process for querying open windows for Windows mode
    property Process windowsProc: Process {
        id: windowsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.cachedWindows = text.trim()
                if (root.currentMode === 3) {
                    root.updateFilteredItems()
                }
            }
        }
    }

    // DesktopEntries change watcher
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.allApps = DesktopEntries.applications.values || []
            if (root.currentMode === 0) {
                root.updateFilteredItems()
            }
        }
    }

    // Main Modal Dialog Card
    Rectangle {
        id: card
        width: Appearance.launcherModalWidth
        height: Appearance.launcherModalHeight
        anchors.centerIn: parent
        radius: Appearance.dialogRadius
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.color: Theme.selection
        border.width: Appearance.borderWidthThin

        // Consume click inside card so backdrop doesn't trigger dismissal
        MouseArea {
            anchors.fill: parent
            onClicked: {
                searchInput.forceActiveFocus()
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: Appearance.paddingXl + 4

            // Top Header: Search prompt, text input, mode buttons
            RowLayout {
                id: topBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Appearance.launcherItemHeight
                spacing: Appearance.spacingLarge

                // Search Prompt icon
                Rectangle {
                    width: Appearance.buttonHeight
                    height: Appearance.buttonHeight
                    radius: Appearance.radiusMedium
                    color: Theme.dark_background
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: Icons.search
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.sizeMedium
                        color: Theme.muted
                    }
                }

                // Search TextInput
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Appearance.spacingSmall
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: root.currentMode === 0 ? "Search applications..." : (root.currentMode === 1 ? "Type a command to run..." : (root.currentMode === 2 ? "Search files..." : "Search open windows..."))
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeRegular
                        color: Theme.muted
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: Appearance.spacingSmall
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeRegular
                        color: Theme.foreground
                        selectionColor: Theme.selection
                        selectedTextColor: Theme.bright_foreground
                        clip: true
                        focus: true

                        onTextChanged: {
                            root.updateFilteredItems()
                            listView.currentIndex = 0
                        }

                        Keys.onDownPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex + 1) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onUpPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex - 1 + listView.count) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: root.executeCurrentItem()
                        Keys.onEnterPressed: root.executeCurrentItem()

                        Keys.onEscapePressed: root.close()

                        Keys.onTabPressed: root.cycleMode(true)
                        Keys.onBacktabPressed: root.cycleMode(false)

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_PageDown) {
                                if (listView.count > 0) {
                                    listView.currentIndex = Math.min(listView.count - 1, listView.currentIndex + 5)
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_PageUp) {
                                if (listView.count > 0) {
                                    listView.currentIndex = Math.max(0, listView.currentIndex - 5)
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            }
                        }
                    }
                }

                // Mode Switcher Pills: Apps | Run | Files | Windows
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Appearance.spacingMedium - 2

                    // Apps Mode Pill
                    Rectangle {
                        width: 58
                        height: 28
                        radius: Appearance.radiusMedium
                        color: root.currentMode === 0 ? Theme.accent : (appsMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)

                        Text {
                            anchors.centerIn: parent
                            text: "Apps"
                            font.family: Fonts.uiFont
                            font.pixelSize: 12
                            font.bold: root.currentMode === 0 
                            color: root.currentMode === 0 ? Theme.darker_background : Theme.foreground
                        }

                        MouseArea {
                            id: appsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setMode(0)
                        }
                    }

                    // Run Mode Pill
                    Rectangle {
                        width: 52
                        height: 28
                        radius: Appearance.radiusMedium
                        color: root.currentMode === 1 ? Theme.accent : (runMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)

                        Text {
                            anchors.centerIn: parent
                            text: "Run"
                            font.family: Fonts.uiFont
                            font.pixelSize: 12
                            font.bold: root.currentMode === 1 
                            color: root.currentMode === 1 ? Theme.darker_background : Theme.foreground
                        }

                        MouseArea {
                            id: runMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setMode(1)
                        }
                    }

                    // Files Mode Pill
                    Rectangle {
                        width: 54
                        height: 28
                        radius: Appearance.radiusMedium
                        color: root.currentMode === 2 ? Theme.accent : (filesMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)

                        Text {
                            anchors.centerIn: parent
                            text: "Files"
                            font.family: Fonts.uiFont
                            font.pixelSize: 12
                            font.bold: root.currentMode === 2 
                            color: root.currentMode === 2 ? Theme.darker_background : Theme.foreground
                        }

                        MouseArea {
                            id: filesMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setMode(2)
                        }
                    }

                    // Windows Mode Pill
                    Rectangle {
                        width: 58
                        height: 28
                        radius: Appearance.radiusMedium
                        color: root.currentMode === 3 ? Theme.accent : (winMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)

                        Text {
                            anchors.centerIn: parent
                            text: "Windows"
                            font.family: Fonts.uiFont
                            font.pixelSize: 12
                            font.bold: root.currentMode === 3 
                            color: root.currentMode === 3 ? Theme.darker_background : Theme.foreground
                        }

                        MouseArea {
                            id: winMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setMode(3)
                        }
                    }
                }
            }

            // Results List Container
            Item {
                anchors.top: topBar.bottom
                anchors.topMargin: Appearance.spacingXl
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.rightMargin: Appearance.spacingLarge
                    clip: true
                    spacing: Appearance.spacingSmall
                    model: root.currentItems

                    delegate: Rectangle {
                        id: rowDelegate
                        required property var modelData
                        required property int index

                        width: listView.width
                        height: 42
                        radius: Appearance.launcherItemRadius

                        readonly property bool isSelected: listView.currentIndex === index
                        readonly property bool isHovered: itemMouse.containsMouse

                        color: isSelected
                            ? Theme.accent
                            : (isHovered ? Theme.lighter_background : Theme.dark_background)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.spacingLarge
                            anchors.rightMargin: Appearance.spacingLarge
                            spacing: Appearance.spacingLarge

                            // App / Item Icon
                            Image {
                                Layout.preferredWidth: Appearance.launcherIconSize
                                Layout.preferredHeight: Appearance.launcherIconSize
                                Layout.alignment: Qt.AlignVCenter
                                fillMode: Image.PreserveAspectFit
                                source: modelData.icon || "image://icon/application-x-executable"
                                sourceSize: Qt.size(Appearance.launcherIconSize, Appearance.launcherIconSize)
                            }

                            // App Name
                            Text {
                                text: modelData.name || ""
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeRegular
                                font.weight: Font.Medium
                                color: isSelected ? Theme.darker_background : Theme.foreground
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Optional Generic Description in parentheses
                            Text {
                                visible: (modelData.generic || "") !== ""
                                text: "(" + (modelData.generic || "") + ")"
                                font.family: Fonts.uiFont
                                font.pixelSize: 12
                                font.italic: true
                                font.weight: Font.Light
                                color: isSelected ? Theme.dark_foreground : Theme.muted
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Spacer item ensuring left alignment
                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: {
                                if (listView.currentIndex !== index) {
                                    listView.currentIndex = index
                                }
                            }
                            onClicked: {
                                listView.currentIndex = index
                                root.executeCurrentItem()
                            }
                        }
                    }
                }

                // Scrollbar
                Rectangle {
                    id: scrollbarTrack
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 5
                    radius: 10
                    color: Theme.dark_background
                    visible: listView.count > 8

                    Rectangle {
                        id: scrollbarHandle
                        width: parent.width
                        radius: 10
                        color: Theme.accent

                        height: Math.max(20, listView.visibleArea.heightRatio * scrollbarTrack.height)
                        y: listView.visibleArea.yPosition * scrollbarTrack.height
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.allApps = DesktopEntries.applications.values || []
    }
}
