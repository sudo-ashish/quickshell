import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"
import "../services"
import "../widgets"
import "../components"

PanelWindow {
    id: root

    required property WorkspacesService workspacesService
    required property AudioService audioService
    required property BrightnessService brightnessService
    required property BatteryService batteryService
    required property NetworkService networkService
    required property BluetoothService bluetoothService
    required property PowerService powerService

    // Bar layout mode configuration (floating, islands, wide, compact)
    property string barMode: "floating"

    // Configuration file watcher for dynamic mode changes
    property FileView barStyleFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar-style"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase()
            if (raw === "compact" || raw === "floating" || raw === "islands" || raw === "wide") {
                root.barMode = raw
            } else {
                root.barMode = "floating"
            }
        }
    }

    readonly property bool isCompact: barMode === "compact"
    readonly property bool isWide: barMode === "wide"
    readonly property bool isIslands: barMode === "islands"
    readonly property bool isFloating: barMode === "floating"
    readonly property bool hasSideAnchors: isFloating || isIslands

    // Panel anchors: top attached, sides attached only in full-width modes
    anchors {
        top: true
        left: root.hasSideAnchors
        right: root.hasSideAnchors
    }

    // Outer screen margins for floating appearance
    margins {
        left: Appearance.barMarginHorizontal
        right: Appearance.barMarginHorizontal
        top: 0
        bottom: 0
    }

    readonly property real totalContentWidth: leftSection.width + clockWidget.width + rightSection.width + (Appearance.barSectionSpacing * 4)

    implicitHeight: Appearance.barHeight
    implicitWidth: root.isCompact
        ? Math.round(root.totalContentWidth + (Appearance.barMarginHorizontal * 2))
        : (root.isWide
            ? Math.round((root.screen ? root.screen.width : 1920) * 0.72)
            : (root.screen ? root.screen.width - (Appearance.barMarginHorizontal * 2) : 1896))

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Auto

    // Unified background surface with rounded bottom corners (floating, wide, compact modes)
    Rectangle {
        id: barBackground
        visible: !root.isIslands
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Appearance.barRadius > 0 ? Appearance.barRadius : 16
        bottomRightRadius: Appearance.barRadius > 0 ? Appearance.barRadius : 16
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.color: Appearance.barBorder ? Theme.selection : "transparent"
        border.width: Appearance.barBorder ? Appearance.borderWidthThin : 0
    }

    // Left island capsule (islands mode)
    Rectangle {
        id: leftIslandBg
        visible: root.isIslands
        x: leftSection.x - 6
        y: Math.round((parent.height - height) / 2)
        width: leftSection.width + 12
        height: Appearance.barButtonHeight + 4
        radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.color: Appearance.barBorder ? Theme.selection : "transparent"
        border.width: Appearance.barBorder ? Appearance.borderWidthThin : 0
    }

    // Center island capsule (islands mode)
    Rectangle {
        id: centerIslandBg
        visible: root.isIslands
        x: clockWidget.x - 8
        y: Math.round((parent.height - height) / 2)
        width: clockWidget.width + 16
        height: Appearance.barButtonHeight + 4
        radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.color: Appearance.barBorder ? Theme.selection : "transparent"
        border.width: Appearance.barBorder ? Appearance.borderWidthThin : 0
    }

    // Right island capsule (islands mode)
    Rectangle {
        id: rightIslandBg
        visible: root.isIslands
        x: rightSection.x - 6
        y: Math.round((parent.height - height) / 2)
        width: rightSection.width + 12
        height: Appearance.barButtonHeight + 4
        radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.color: Appearance.barBorder ? Theme.selection : "transparent"
        border.width: Appearance.barBorder ? Appearance.borderWidthThin : 0
    }

    // Widget content container
    Item {
        id: barContainer
        anchors.fill: parent

        // Left section: workspace switcher and media pill
        Row {
            id: leftSection
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSectionSpacing
            width: implicitWidth
            height: implicitHeight
            x: root.isCompact
                ? Math.round((barContainer.width - root.totalContentWidth) / 2)
                : Appearance.barMarginHorizontal

            WorkspacesWidget {
                service: root.workspacesService
            }

            NowBarPill {
                audioService: root.audioService
            }
        }

        // Center section: date and clock
        ClockWidget {
            id: clockWidget
            anchors.verticalCenter: parent.verticalCenter
            x: root.isCompact
                ? (leftSection.x + leftSection.width + (Appearance.barSectionSpacing * 2))
                : Math.round((barContainer.width - width) / 2)
            powerService: root.powerService
        }

        // Right section: hardware and status controls
        Row {
            id: rightSection
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSpacing
            width: implicitWidth
            height: implicitHeight
            x: root.isCompact
                ? (clockWidget.x + clockWidget.width + (Appearance.barSectionSpacing * 2))
                : Math.round(barContainer.width - width - Appearance.barMarginHorizontal)

            BluetoothWidget {
                id: bluetoothWidget
                service: root.bluetoothService
            }

            NetworkWidget {
                id: networkWidget
                service: root.networkService
            }

            AudioWidget {
                id: audioWidget
                service: root.audioService
            }

            MonitorWidget {
                id: monitorWidget
                service: root.brightnessService
            }

            BatteryWidget {
                id: batteryWidget
                batteryService: root.batteryService
                powerService: root.powerService
            }
        }
    }

    // IPC handler for external popup toggles and bar mode control
    IpcHandler {
        target: "barpopups"

        function toggle(name: string): string {
            if (name === "clock") clockWidget.toggle()
            else if (name === "monitor") monitorWidget.toggle()
            else if (name === "battery") batteryWidget.toggle()
            else if (name === "network") networkWidget.toggle()
            else if (name === "audio") audioWidget.toggle()
            else if (name === "bluetooth") bluetoothWidget.toggle()
            return "ok"
        }

        function setMode(newMode: string): string {
            if (newMode === "compact" || newMode === "floating" || newMode === "islands" || newMode === "wide") {
                root.barMode = newMode
                return "ok: " + newMode
            }
            return "error: unknown mode"
        }

        function getMode(): string {
            return root.barMode
        }
    }
}
