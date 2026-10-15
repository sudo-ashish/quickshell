pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Central single source of truth path for colors configuration
    readonly property string colorsConfigPath: Quickshell.env("HOME") + "/.config/themes/current/colors.toml"
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

    readonly property real baseOpacity: root.blurEnabled ? 0.82 : 1.0
    readonly property real elevatedOpacity: root.blurEnabled ? 0.88 : 1.0
    readonly property real layerOpacity: 0.28
    readonly property real scrimOpacity: 0.35

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
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"quickshell-caelestia-blur\", match = { namespace = \"^quickshell-.*\" }, blur = true, blur_popups = true, ignore_alpha = 0.57 })' 2>/dev/null || true"
        } else {
            cmd += " && hyprctl keyword layerrule \"unset, ^(quickshell-.*)$\" 2>/dev/null || true"
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"quickshell-caelestia-blur\", match = { namespace = \"^quickshell-.*\" }, blur = false, blur_popups = false })' 2>/dev/null || true"
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

    // Typography & Metrics
    property int baseTextSize: 12

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSizeSmall: Math.max(8, Math.round(baseTextSize * 0.917))
    readonly property int fontSizeRegular: Math.max(9, Math.round(baseTextSize * 1.083))
    readonly property int fontSizeMedium: Math.max(10, Math.round(baseTextSize * 1.167))
    readonly property int fontSizeLarge: Math.max(12, Math.round(baseTextSize * 1.333))
    readonly property int fontSizeTitle: Math.max(16, Math.round(baseTextSize * 1.833))

    readonly property int barHeight: Math.max(26, Math.round(baseTextSize * 2.5))
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12

    readonly property int animDuration: 150

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
            root.parseThemeFile(text())
        }
    }

    Component.onCompleted: {
        if (colorsFile.text()) {
            root.parseThemeFile(colorsFile.text())
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
