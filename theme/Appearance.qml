pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // =========================================================================
    // Bar Dimensions & Layout
    // =========================================================================
    // Bar height reactively derived from base text size (default ~30px at base 12)
    property int barHeight: Math.max(26, Math.round(Fonts.baseTextSize * 2.5))

    // Bar corner radius (0 for edge-to-edge top bar, >0 for floating pill bar)
    property int barRadius: 0

    // Horizontal margins for the outer bar window
    property int barMarginHorizontal: 12

    // Internal spacing between status widgets in the bar
    property int barSpacing: 4

    // Spacing between left bar sections (workspaces, now-playing pill)
    property int barSectionSpacing: 8

    // Standard button height on the bar
    property int barButtonHeight: barHeight - 4

    // =========================================================================
    // Bar Widget Icons & Display Options
    // =========================================================================
    // Toggle whether battery percentage is shown on the bar next to the icon (default: false)
    property bool batteryShowPercentage: false

    // Individual bar widget icon sizes (px)
    property int barIconSize: Icons.barIconSize
    property int batteryIconSize: 22
    property int audioIconSize: root.barIconSize
    property int bluetoothIconSize: root.barIconSize
    property int networkIconSize: root.barIconSize
    property int monitorIconSize: root.barIconSize
    property int workspacesIconSize: Icons.workspacesIconSize

    // =========================================================================
    // Corner Radii
    // =========================================================================
    property int radiusXs: 2
    property int radiusSmall: 4
    property int radiusMedium: 8
    property int radiusLarge: 12
    property int radiusXl: 14
    property int radiusPill: 24

    // Semantic component radii
    property int buttonRadius: root.radiusSmall
    property int popupRadius: root.radiusMedium
    property int cardRadius: root.radiusLarge
    property int dialogRadius: root.radiusXl
    property int surfaceRadius: 10

    // =========================================================================
    // Borders & Outlines
    // =========================================================================
    property int borderWidthNone: 0
    property int borderWidthThin: 1
    property int borderWidthMedium: 2
    property int borderWidthThick: 3
    property int defaultBorderWidth: root.borderWidthThin

    // =========================================================================
    // Padding & Spacing
    // =========================================================================
    property int spacingXs: 2
    property int spacingSmall: 4
    property int spacingMedium: 8
    property int spacingLarge: 12
    property int spacingXl: 16

    property int paddingSmall: 6
    property int paddingMedium: 10
    property int paddingLarge: 14
    property int paddingXl: 20

    // Popup card geometry
    property int popupPadding: 12
    property int popupMargin: 8
    property int popupHeaderHeight: 38

    // =========================================================================
    // Button & Control Dimensions
    // =========================================================================
    property int buttonHeight: 32
    property int buttonPadding: 8

    // =========================================================================
    // Sliders
    // =========================================================================
    // Standard popup slider
    property int sliderWidth: 260
    property int sliderHeight: 34
    property int sliderTrackHeight: 8
    property int sliderTrackRadius: 4
    property int sliderKnobSize: 16
    property int sliderKnobRadius: 8
    property int sliderKnobBorderWidth: 2
    property int sliderSpacing: 10

    // Compact audio mixer slider
    property int audioSliderHeight: 22
    property int audioSliderTrackHeight: 4
    property int audioSliderTrackRadius: 2

    // =========================================================================
    // Toggle Switches
    // =========================================================================
    property int toggleTrackWidth: 40
    property int toggleTrackHeight: 22
    property int toggleTrackRadius: 2
    property int toggleThumbSize: 16
    property int toggleThumbRadius: 2
    property int toggleBorderWidth: 1

    // =========================================================================
    // On-Screen Display (OSD)
    // =========================================================================
    property int osdHeight: 48
    property int osdRadius: 24
    property int osdBottomMargin: 64
    property int osdSpacing: 14
    property int osdTrackWidth: 140
    property int osdTrackHeight: 6
    property int osdTrackRadius: 3

    // =========================================================================
    // Notifications
    // =========================================================================
    property int notificationWidth: 380
    property int notificationRadius: root.radiusLarge
    property int notificationRightMargin: 16
    property int notificationTopMargin: root.barHeight + 12
    property int notificationSpacing: 8
    property int notificationUrgencyStripWidth: 4

    // =========================================================================
    // Application Launcher
    // =========================================================================
    property int launcherWidth: 600
    property int launcherHeight: 410
    property int launcherModalWidth: 700
    property int launcherModalHeight: 468
    property int launcherRadius: 10
    property int launcherPadding: 30
    property int launcherItemHeight: 36
    property int launcherItemRadius: 10
    property int launcherIconSize: 24

    // =========================================================================
    // Power & Unified Menu
    // =========================================================================
    property int powerMenuRadiusActive: 14
    property int powerMenuRadiusInactive: 32
    property int powerMenuWidthPower: 380
    property int powerMenuHeightPower: 136
    property int powerMenuHeightTheme: 252
    property int powerMenuHeightWallpaper: 196

    // =========================================================================
    // Media Controls & Pills
    // =========================================================================
    property int mediaPillHeight: 28
    property int mediaPillRadius: root.radiusMedium
    property int mediaPopupWidth: 350
    property int mediaPopupHeight: 195
    property int mediaIslandWidth: 340
    property int mediaIslandHeight: 140
    property int mediaIslandRadius: 22

    // =========================================================================
    // Opacity & Transparency Tokens
    // =========================================================================
    property real baseOpacity: 0.82
    property real elevatedOpacity: 0.88
    property real layerOpacity: 0.28
    property real scrimOpacity: 0.35
    property real subtleOpacity: 0.60
    property real disabledOpacity: 0.38

    // =========================================================================
    // Animation Durations (ms)
    // =========================================================================
    property int animDurationFast: 100
    property int animDurationNormal: 150
    property int animDurationMedium: 200
    property int animDurationSlow: 250
    property int animDurationSpring: 320
}
