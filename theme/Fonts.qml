pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // =========================================================================
    // Font Families
    // =========================================================================
    // Primary user interface font family
    property string uiFont: "JetBrainsMono Nerd Font"

    // Monospace font family for code, terminals, and aligned data
    property string monoFont: "JetBrainsMono Nerd Font"

    // Primary font family for icon glyphs (e.g., Nerd Font or Material Symbols)
    property string iconFont: "JetBrainsMono Nerd Font"

    // Google Material Symbols font family (locally installed or system-provided)
    property string symbolFont: "Material Symbols Rounded"

    // =========================================================================
    // Base Text Size & Scaling
    // =========================================================================
    // Root text size (in pixels). Changing this dynamically scales all derived sizes.
    property int baseTextSize: 12

    // Watcher for external text-size configuration updates (e.g. from qdeck-display-text-size)
    property FileView textSizeFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/text-size"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim()
            var commentIdx = raw.indexOf("#")
            if (commentIdx !== -1) raw = raw.slice(0, commentIdx).trim()
            var s = parseInt(raw, 10)
            if (!isNaN(s) && s >= 8 && s <= 32) {
                root.baseTextSize = s
            }
        }
    }

    // =========================================================================
    // Semantic Font Sizes (Reactively scaled from baseTextSize)
    // =========================================================================
    // Extra small (badges, tiny meta, captions, subscripts)
    readonly property int sizeXs: Math.max(7, Math.round(baseTextSize * 0.75))       // ~9px at base 12
    readonly property int sizeSmall: Math.max(8, Math.round(baseTextSize * 0.917))   // ~11px at base 12
    readonly property int sizeRegular: Math.max(9, Math.round(baseTextSize * 1.083)) // ~13px at base 12
    readonly property int sizeMedium: Math.max(10, Math.round(baseTextSize * 1.167)) // ~14px at base 12
    readonly property int sizeLarge: Math.max(12, Math.round(baseTextSize * 1.333))  // ~16px at base 12
    readonly property int sizeTitle: Math.max(16, Math.round(baseTextSize * 1.833))  // ~22px at base 12
    readonly property int sizeDisplay: Math.max(22, Math.round(baseTextSize * 2.333))// ~28px at base 12
    readonly property int sizeHero: Math.max(26, Math.round(baseTextSize * 2.833))   // ~34px at base 12
    readonly property int sizeGiant: Math.max(30, Math.round(baseTextSize * 3.167))  // ~38px at base 12

    // Helper function to scale an arbitrary pixel size proportionally to baseTextSize (relative to default 12px)
    function scale(px) {
        return Math.max(6, Math.round(px * (root.baseTextSize / 12.0)))
    }

    // =========================================================================
    // Font Weights
    // =========================================================================
    readonly property int weightThin: Font.Thin
    readonly property int weightLight: Font.Light
    readonly property int weightNormal: Font.Normal
    readonly property int weightMedium: Font.Medium
    readonly property int weightDemiBold: Font.DemiBold
    readonly property int weightBold: Font.Bold
    readonly property int weightBlack: Font.Black

    // =========================================================================
    // Backward-Compatible Property Aliases
    // =========================================================================
    readonly property alias fontFamily: root.uiFont
    readonly property alias fontSizeSmall: root.sizeSmall
    readonly property alias fontSizeRegular: root.sizeRegular
    readonly property alias fontSizeMedium: root.sizeMedium
    readonly property alias fontSizeLarge: root.sizeLarge
    readonly property alias fontSizeTitle: root.sizeTitle
}
