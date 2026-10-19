import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../components"
import "LauncherModel.js" as LauncherModel

PanelWindow {
    id: root

    readonly property string fontFamily: Fonts.uiFont

    property bool isOpen: false
    property var allApps: []
    property var filteredApps: []

    function open(initialQuery) {
        root.isOpen = true
        root.loadApps()
        searchInput.text = (typeof initialQuery === "string") ? initialQuery : ""
        root.filterApps()
        listView.currentIndex = 0
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function close() {
        root.isOpen = false
        searchInput.text = ""
        listView.currentIndex = 0
    }

    function toggle(initialQuery) {
        if (root.isOpen) {
            root.close()
        } else {
            root.open(initialQuery)
        }
    }

    function loadApps() {
        root.allApps = DesktopEntries.applications.values || []
    }

    function filterApps() {
        var q = searchInput.text.trim()
        root.filteredApps = LauncherModel.filterApps(root.allApps, q)
        if (listView.currentIndex >= root.filteredApps.length) {
            listView.currentIndex = 0
        }
    }

    function executeCurrentItem() {
        if (!root.filteredApps || root.filteredApps.length === 0) return

        var item = root.filteredApps[listView.currentIndex]
        if (!item) return

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

        root.close()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Window Setup & Native Hyprland Blur Integration
    // ─────────────────────────────────────────────────────────────────────────
    visible: root.isOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Dynamic screen binding to Hyprland focused monitor
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

    // IPC interface for qdeck-launcher CLI compatibility
    IpcHandler {
        target: "launcher"
        function open(): void { root.open("") }
        function search(query: string): void { root.open(query) }
        function close(): void { root.close() }
        function toggle(): void { root.toggle("") }
        function setMode(mode: string): void { root.open("") }
    }

    // Full-screen Backdrop Scrim (Tier 2 alpha <= 0.35 -> will NOT blur)
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: root.close()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.loadApps()
            root.filterApps()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Launcher Surface (Rofi style-3 replication)
    // ─────────────────────────────────────────────────────────────────────────
    ShellSurface {
        id: surface
        width: Appearance.launcherWidth
        height: Appearance.launcherHeight
        anchors.centerIn: parent

        surfaceRadius: Appearance.launcherRadius
        surfaceColor: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        borderColor: "transparent"
        borderWidth: Appearance.borderWidthNone

        // Consume clicks inside card so backdrop doesn't trigger dismissal
        MouseArea {
            anchors.fill: parent
            onClicked: searchInput.forceActiveFocus()
        }

        // Main Box with padding and spacing
        Item {
            anchors.fill: parent
            anchors.margins: Appearance.launcherPadding

            // ── Inputbar ─────────────────────────────────────────────────────
            RowLayout {
                id: inputbar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Appearance.buttonHeight
                spacing: Appearance.spacingMedium + 2

                // Prompt glyph
                Text {
                    id: promptGlyph
                    text: Icons.search
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Fonts.sizeMedium
                    color: Theme.foreground
                    Layout.alignment: Qt.AlignVCenter
                }

                // Search Entry
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Placeholder text
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search..."
                        font.family: root.fontFamily
                        font.pixelSize: Fonts.sizeRegular
                        color: Theme.muted
                        visible: searchInput.text.length === 0
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.fontFamily
                        font.pixelSize: Fonts.sizeRegular
                        color: Theme.foreground
                        selectionColor: Theme.selection
                        selectedTextColor: Theme.bright_foreground
                        clip: true
                        focus: true

                        onTextChanged: {
                            root.filterApps()
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

                        Keys.onTabPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex + 1) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onBacktabPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex - 1 + listView.count) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: root.executeCurrentItem()
                        Keys.onEnterPressed: root.executeCurrentItem()
                        Keys.onEscapePressed: root.close()

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
            }

            // ── Listview ─────────────────────────────────────────────────────
            Item {
                anchors.top: inputbar.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.rightMargin: scrollbar.visible ? 10 : 0
                    clip: true
                    spacing: 5
                    model: root.filteredApps

                    delegate: Rectangle {
                        id: element
                        required property var modelData
                        required property int index

                        width: listView.width
                        height: Appearance.launcherItemHeight
                        radius: Appearance.launcherItemRadius

                        readonly property bool isSelected: listView.currentIndex === index
                        readonly property bool isHovered: itemMouse.containsMouse

                        // Element normal / selected background
                        color: isSelected
                            ? Theme.accent
                            : (isHovered ? Theme.withAlpha(Theme.lighter_background, Theme.layerOpacity) : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.paddingMedium
                            anchors.rightMargin: Appearance.paddingMedium
                            spacing: Appearance.spacingMedium + 2

                            // Element Icon container with graceful fallback badge
                            Item {
                                Layout.preferredWidth: Appearance.launcherIconSize
                                Layout.preferredHeight: Appearance.launcherIconSize
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    id: appIconImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: modelData.icon || ""
                                    sourceSize: Qt.size(Appearance.launcherIconSize, Appearance.launcherIconSize)
                                    visible: status === Image.Ready && (modelData.icon || "") !== ""
                                }

                                Rectangle {
                                    id: fallbackBadge
                                    anchors.fill: parent
                                    radius: Appearance.radiusSmall + 2
                                    visible: !appIconImg.visible
                                    color: element.isSelected ? Theme.selection : Theme.withAlpha(Theme.accent, 0.20)
                                    border.color: element.isSelected ? Theme.accent : Theme.selection
                                    border.width: Appearance.borderWidthThin

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (modelData.name && modelData.name.length > 0) {
                                                return modelData.name.charAt(0).toUpperCase()
                                            }
                                            return Icons.apps
                                        }
                                        font.family: root.fontFamily
                                        font.pixelSize: Fonts.sizeSmall
                                        font.weight: Fonts.weightBold
                                        color: element.isSelected ? Theme.darker_background : Theme.accent
                                    }
                                }
                            }

                            // App Name
                            Text {
                                text: modelData.name || ""
                                font.family: root.fontFamily
                                font.pixelSize: Fonts.sizeRegular
                                font.weight: element.isSelected ? Fonts.weightBold : Fonts.weightMedium
                                color: element.isSelected ? Theme.darker_background : Theme.foreground
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Generic Name: (Web Browser), (Text Editor) in italics
                            Text {
                                visible: (modelData.generic || "") !== ""
                                text: "(" + (modelData.generic || "") + ")"
                                font.family: root.fontFamily
                                font.pixelSize: Fonts.sizeSmall
                                font.italic: true
                                font.weight: Fonts.weightLight
                                color: element.isSelected ? Theme.dark_background : Theme.muted
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Spacer to ensure left alignment
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

                // ── Scrollbar ────────────────────────────────────────────────
                Rectangle {
                    id: scrollbar
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

                        height: Math.max(20, listView.visibleArea.heightRatio * scrollbar.height)
                        y: listView.visibleArea.yPosition * scrollbar.height
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.loadApps()
    }
}
