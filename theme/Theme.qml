pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Central single source of truth path for colors configuration
    readonly property string colorsConfigPath: Quickshell.env("HOME") + "/.config/themes/current/colors.toml"
    readonly property string localColorsPath: (Quickshell.env("QS_CONFIG_PATH") || (Quickshell.env("HOME") + "/.config/quickshell")) + "/theme/colors.toml"
    readonly property string blurStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/blur-state"

    // Raw parsed colors dictionary
    property var _c: ({})

    // Strict color schema
    readonly property color accent: _c.accent || "transparent"
    readonly property color selection: _c.selection || "transparent"
    readonly property color muted: _c.muted || "transparent"

    readonly property color background: _c.background || "transparent"
    readonly property color dark_background: _c.dark_background || "transparent"
    readonly property color darker_background: _c.darker_background || "transparent"
    readonly property color lighter_background: _c.lighter_background || "transparent"

    readonly property color foreground: _c.foreground || "transparent"
    readonly property color dark_foreground: _c.dark_foreground || "transparent"
    readonly property color light_foreground: _c.light_foreground || "transparent"
    readonly property color bright_foreground: _c.bright_foreground || "transparent"

    readonly property color red: _c.red || "transparent"
    readonly property color urgent: root.red
    readonly property color yellow: _c.yellow || "transparent"
    readonly property color orange: _c.orange || "transparent"
    readonly property color green: _c.green || "transparent"
    readonly property color cyan: _c.cyan || "transparent"
    readonly property color blue: _c.blue || "transparent"
    readonly property color magenta: _c.magenta || "transparent"
    readonly property color brown: _c.brown || "transparent"

    readonly property color bright_red: _c.bright_red || "transparent"
    readonly property color bright_yellow: _c.bright_yellow || "transparent"
    readonly property color bright_green: _c.bright_green || "transparent"
    readonly property color bright_cyan: _c.bright_cyan || "transparent"
    readonly property color bright_blue: _c.bright_blue || "transparent"
    readonly property color bright_magenta: _c.bright_magenta || "transparent"

    // ─────────────────────────────────────────────────────────────────────────
    // Dual Alpha + Compositor Blur Architecture
    // ─────────────────────────────────────────────────────────────────────────
    property bool blurEnabled: true

    readonly property real baseOpacity: root.blurEnabled ? Appearance.baseOpacity : 1.0
    readonly property real elevatedOpacity: root.blurEnabled ? Appearance.elevatedOpacity : 1.0
    readonly property real layerOpacity: Appearance.layerOpacity
    readonly property real scrimOpacity: Appearance.scrimOpacity

    function withAlpha(colorVal, alphaVal) {
        return Qt.rgba(colorVal.r, colorVal.g, colorVal.b, alphaVal)
    }

    function setBlurState(enabled) {
        root.blurEnabled = enabled
        var stateStr = enabled ? "on" : "off"
        var cmd = "mkdir -p \"$(dirname \"" + root.blurStatePath + "\")\" && printf '%s' \"" + stateStr + "\" > \"" + root.blurStatePath + "\""
        if (enabled) {
            cmd += " && hyprctl keyword layerrule \"unset, ^(quickshell-.*)$\" 2>/dev/null || true"
            cmd += " && hyprctl keyword layerrule \"blur, ^(quickshell-.*)$\" 2>/dev/null || true"
            cmd += " && hyprctl keyword layerrule \"blurpopups, ^(quickshell-.*)$\" 2>/dev/null || true"
            cmd += " && hyprctl keyword layerrule \"ignorealpha 0.57, ^(quickshell-.*)$\" 2>/dev/null || true"
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"qdeck-blur\", match = { namespace = \"^quickshell-.*\" }, blur = true, blur_popups = true, ignore_alpha = 0.57 })' 2>/dev/null || true"
        } else {
            cmd += " && hyprctl keyword layerrule \"unset, ^(quickshell-.*)$\" 2>/dev/null || true"
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"qdeck-blur\", match = { namespace = \"^quickshell-.*\" }, blur = false, blur_popups = false })' 2>/dev/null || true"
        }
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    // IPC Interface for theme / blur control
    property IpcHandler ipcHandler: IpcHandler {
        target: "theme"

        function toggleBlur(): string {
            root.setBlurState(!root.blurEnabled)
            return root.blurEnabled ? "on" : "off"
        }

        function setBlur(mode: string): string {
            var m = String(mode || "").trim().toLowerCase()
            if (m === "on" || m === "true" || m === "1") root.setBlurState(true)
            else if (m === "off" || m === "false" || m === "0") root.setBlurState(false)
            return root.blurEnabled ? "on" : "off"
        }

        function getBlur(): string {
            return root.blurEnabled ? "on" : "off"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Typography & Metrics Bridges (Centralized in Fonts & Appearance)
    // ─────────────────────────────────────────────────────────────────────────
    property int baseTextSize: Fonts.baseTextSize
    onBaseTextSizeChanged: {
        if (Fonts.baseTextSize !== baseTextSize) {
            Fonts.baseTextSize = baseTextSize
        }
    }

    readonly property string fontFamily: Fonts.uiFont
    readonly property int fontSizeSmall: Fonts.sizeSmall
    readonly property int fontSizeRegular: Fonts.sizeRegular
    readonly property int fontSizeMedium: Fonts.sizeMedium
    readonly property int fontSizeLarge: Fonts.sizeLarge
    readonly property int fontSizeTitle: Fonts.sizeTitle

    readonly property int barHeight: Appearance.barHeight
    readonly property int radiusSmall: Appearance.radiusSmall
    readonly property int radiusMedium: Appearance.radiusMedium
    readonly property int radiusLarge: Appearance.radiusLarge

    readonly property int animDuration: Appearance.animDurationNormal

    property FileView blurStateFile: FileView {
        path: root.blurStatePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase()
            if (raw === "off" || raw === "false" || raw === "0") {
                if (root.blurEnabled) root.blurEnabled = false
            } else if (raw === "on" || raw === "true" || raw === "1") {
                if (!root.blurEnabled) root.blurEnabled = true
            }
        }
    }

    function parseThemeFile(rawText) {
        var lines = String(rawText || "").split("\n")
        var map = {}
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line || line.startsWith("#") || line.startsWith(";")) continue
            var eqIdx = line.indexOf("=")
            if (eqIdx < 1) continue
            var key = line.slice(0, eqIdx).trim()
            var rawVal = line.slice(eqIdx + 1).trim()
            var val = ""

            var quotedMatch = rawVal.match(/^["']([^"']*)["']/)
            if (quotedMatch) {
                val = quotedMatch[1].trim()
            } else {
                var hashIdx = rawVal.indexOf("#")
                var semiIdx = rawVal.indexOf(";")
                var cutIdx = -1
                if (hashIdx !== -1 && semiIdx !== -1) cutIdx = Math.min(hashIdx, semiIdx)
                else if (hashIdx !== -1) cutIdx = hashIdx
                else if (semiIdx !== -1) cutIdx = semiIdx

                if (cutIdx !== -1) {
                    val = rawVal.slice(0, cutIdx).trim()
                } else {
                    val = rawVal.trim()
                }
                val = val.replace(/^['"]+|['";\s]+$/g, "").trim()
            }

            if (val) {
                map[key] = val
            }
        }
        root._c = map
    }

    property FileView colorsFile: FileView {
        path: root.colorsConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (text()) root.parseThemeFile(text())
        }
    }

    property FileView fallbackColorsFile: FileView {
        path: root.localColorsPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!colorsFile.text() && text()) {
                root.parseThemeFile(text())
            }
        }
    }

    Component.onCompleted: {
        if (colorsFile.text()) {
            root.parseThemeFile(colorsFile.text())
        } else if (fallbackColorsFile.text()) {
            root.parseThemeFile(fallbackColorsFile.text())
        }

        var rawBlur = String(blurStateFile.text() || "").trim().toLowerCase()
        if (rawBlur === "off" || rawBlur === "false" || rawBlur === "0") {
            root.blurEnabled = false
            root.setBlurState(false)
        } else {
            root.blurEnabled = true
            root.setBlurState(true)
        }
    }
}
