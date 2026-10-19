pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // Icon fonts configuration
    property string iconFont: Fonts.iconFont
    property string symbolFont: (materialSymbolsLoader.name && materialSymbolsLoader.name.length > 0) ? materialSymbolsLoader.name : Fonts.symbolFont
    property bool useMaterialSymbols: true

    // Local font loader for Google Material Symbols Rounded
    property FontLoader materialSymbolsLoader: FontLoader {
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/MaterialSymbolsRounded.ttf"
    }

    // Semantic icon sizes
    readonly property int sizeXs: Fonts.sizeXs
    readonly property int sizeSmall: Fonts.sizeSmall
    readonly property int sizeNormal: Fonts.sizeLarge
    readonly property int sizeMedium: Fonts.sizeTitle
    readonly property int sizeLarge: Fonts.sizeDisplay
    readonly property int sizeDisplay: Fonts.sizeHero
    readonly property int sizeHero: Fonts.sizeGiant

    // Component-level icon sizes
    property int barIconSize: root.sizeNormal
    property int batteryIconSize: root.barIconSize
    property int audioIconSize: root.barIconSize
    property int bluetoothIconSize: root.barIconSize
    property int networkIconSize: root.barIconSize
    property int monitorIconSize: root.barIconSize
    property int workspacesIconSize: root.sizeNormal
    property int mediaIconSize: root.sizeSmall

    // Core action glyphs
    // Core actions
    readonly property string search: root.useMaterialSymbols ? "search" : ""
    readonly property string close: root.useMaterialSymbols ? "close" : "󰅖"
    readonly property string check: root.useMaterialSymbols ? "check" : "󰄬"
    readonly property string cancel: root.useMaterialSymbols ? "cancel" : "󰅖"
    readonly property string settings: root.useMaterialSymbols ? "settings" : "󰒓"
    readonly property string refresh: root.useMaterialSymbols ? "refresh" : "󰑐"
    readonly property string spinner: root.useMaterialSymbols ? "progress_activity" : "󰑮"

    // Power & Session
    readonly property string power: root.useMaterialSymbols ? "power_settings_new" : "󰐥"
    readonly property string reboot: root.useMaterialSymbols ? "restart_alt" : "󰜉"
    readonly property string suspend: root.useMaterialSymbols ? "bedtime" : "󰤄"
    readonly property string lock: root.useMaterialSymbols ? "lock" : "󰌾"
    readonly property string unlock: root.useMaterialSymbols ? "lock_open" : "󰌿"
    readonly property string logout: root.useMaterialSymbols ? "logout" : "󰍃"

    // Media & Audio Controls
    readonly property string music: root.useMaterialSymbols ? "music_note" : "󰝚"
    readonly property string play: root.useMaterialSymbols ? "play_arrow" : "󰐊"
    readonly property string pause: root.useMaterialSymbols ? "pause" : "󰏤"
    readonly property string prev: root.useMaterialSymbols ? "skip_previous" : "󰒮"
    readonly property string next: root.useMaterialSymbols ? "skip_next" : "󰒭"
    readonly property string shuffle: root.useMaterialSymbols ? "shuffle" : "󰒝"
    readonly property string repeat: root.useMaterialSymbols ? "repeat" : "󰑖"
    readonly property string volumeHigh: root.useMaterialSymbols ? "volume_up" : "󰕾"
    readonly property string volumeMedium: root.useMaterialSymbols ? "volume_down" : "󰖀"
    readonly property string volumeLow: root.useMaterialSymbols ? "volume_mute" : "󰕿"
    readonly property string volumeMute: root.useMaterialSymbols ? "volume_off" : "󰝟"
    readonly property string headphones: root.useMaterialSymbols ? "headphones" : "󰋋"
    readonly property string mic: root.useMaterialSymbols ? "mic" : "󰍬"
    readonly property string micOff: root.useMaterialSymbols ? "mic_off" : "󰍭"

    // Hardware & Status
    property string brightness: root.useMaterialSymbols ? "brightness_high" : "󰃠"
    readonly property string display: root.useMaterialSymbols ? "monitor" : "󰍹"
    property string batteryFull: root.useMaterialSymbols ? "battery_android_full" : "󰁹"
    property string batteryCharging: root.useMaterialSymbols ? "battery_android_bolt" : "󰂄"
    property string batteryLow: root.useMaterialSymbols ? "battery_android_alert" : "󰂃"
    property string bluetooth: root.useMaterialSymbols ? "bluetooth" : "󰂯"
    property string bluetoothConnected: root.useMaterialSymbols ? "bluetooth_connected" : "󰂱"
    property string bluetoothDisconnected: root.useMaterialSymbols ? "bluetooth_disabled" : "󰂲"
    property string wifi: root.useMaterialSymbols ? "wifi" : "󰤨"
    property string wifiOff: root.useMaterialSymbols ? "wifi_off" : "󰤭"
    property string ethernet: root.useMaterialSymbols ? "lan" : "󰈀"
    readonly property string bell: root.useMaterialSymbols ? "notifications" : "󰂚"
    readonly property string bellOff: root.useMaterialSymbols ? "notifications_off" : "󰂛"
    readonly property string calendar: root.useMaterialSymbols ? "calendar_month" : "󰃭"
    readonly property string clock: root.useMaterialSymbols ? "schedule" : "󰥔"
    readonly property string keyboard: root.useMaterialSymbols ? "keyboard" : "󰌌"
    readonly property string numlock: root.useMaterialSymbols ? "pin" : "󰎠"
    readonly property string trackpad: root.useMaterialSymbols ? "touchpad" : "󰟸"
    readonly property string trackpadOff: root.useMaterialSymbols ? "touchpad_mouse_off" : "󰤳"

    // Applications & UI
    readonly property string apps: root.useMaterialSymbols ? "apps" : "󰀻"
    readonly property string window: root.useMaterialSymbols ? "window" : "󰖲"
    readonly property string folder: root.useMaterialSymbols ? "folder" : "󰉋"
    readonly property string terminal: root.useMaterialSymbols ? "terminal" : "󰆍"
    readonly property string palette: root.useMaterialSymbols ? "palette" : "󰏘"
    readonly property string wallpaper: root.useMaterialSymbols ? "wallpaper" : "󰋩"

    // Battery icon resolver by capacity and charging state
    function battery(capacity, isCharging) {
        if (root.useMaterialSymbols) {
            if (isCharging) return root.batteryCharging
            if (capacity >= 95) return root.batteryFull
            if (capacity >= 85) return "battery_android_6"
            if (capacity >= 70) return "battery_android_5"
            if (capacity >= 55) return "battery_android_4"
            if (capacity >= 40) return "battery_android_3"
            if (capacity >= 25) return "battery_android_2"
            if (capacity >= 15) return "battery_android_1"
            if (capacity >= 5)  return "battery_android_0"
            return root.batteryLow
        } else {
            if (isCharging) return root.batteryCharging
            if (capacity >= 95) return root.batteryFull
            if (capacity >= 85) return "󰂂"
            if (capacity >= 75) return "󰂁"
            if (capacity >= 65) return "󰂀"
            if (capacity >= 55) return "󰁿"
            if (capacity >= 45) return "󰁾"
            if (capacity >= 35) return "󰁽"
            if (capacity >= 25) return "󰁼"
            if (capacity >= 15) return "󰁻"
            if (capacity >= 5)  return "󰁺"
            return root.batteryLow
        }
    }

    // Wi-Fi signal resolver (Material Symbols arc glyphs have 3 signal stages: wifi, wifi_2_bar, wifi_1_bar)
    function wifiSignal(signal) {
        var sig = parseInt(signal, 10) || 0
        var isMat = root.useMaterialSymbols || (typeof root.wifi === "string" && root.wifi.length > 0 && root.wifi.charCodeAt(0) < 128)
        if (isMat) {
            if (sig >= 66) return root.wifi || "wifi"
            if (sig >= 33) return "wifi_2_bar"
            if (sig > 0) return "wifi_1_bar"
            return root.wifiOff || "wifi_off"
        } else {
            if (sig >= 75) return root.wifi || "󰤨"
            if (sig >= 50) return "󰤥"
            if (sig >= 25) return "󰤢"
            return "󰤟"
        }
    }

    // Dynamic network status icon helper
    function network(connectionType, wifiEnabled, currentSsid, signalStrength) {
        var isMat = root.useMaterialSymbols || (typeof root.wifi === "string" && root.wifi.length > 0 && root.wifi.charCodeAt(0) < 128)
        if (connectionType === "ethernet") return isMat ? "lan" : root.ethernet
        if (!wifiEnabled || !currentSsid) return isMat ? (root.wifiOff && root.wifiOff.charCodeAt(0) < 128 ? root.wifiOff : "wifi_off") : root.wifiOff
        return root.wifiSignal(signalStrength)
    }

    // Dynamic Bluetooth status icon helper
    function bluetoothStatus(enabled, connectedCount) {
        if (!enabled) return root.bluetoothDisconnected
        if (connectedCount > 0) return root.bluetoothConnected
        return root.bluetooth
    }

    // Dynamic Brightness status icon helper
    function brightnessLevel(brightness) {
        if (root.useMaterialSymbols) {
            if (brightness < 33) return "brightness_low"
            if (brightness < 66) return "brightness_medium"
            return root.brightness || "brightness_high"
        } else {
            if (brightness < 33) return "󰃞"
            if (brightness < 66) return "󰃟"
            return root.brightness || "󰃠"
        }
    }

    // Dynamic Volume level helper
    function volumeLevel(vol, isMuted, isHeadphones) {
        if (isHeadphones) return root.headphones
        if (isMuted || vol <= 0) return root.volumeMute
        if (vol < 33) return root.volumeLow
        if (vol < 66) return root.volumeMedium
        return root.volumeHigh
    }

    // Dynamic Mic level helper
    function micLevel(isMuted) {
        return isMuted ? root.micOff : root.mic
    }

    // Helper function to safely resolve an icon by semantic name with a fallback
    function get(name, fallback) {
        if (root[name] !== undefined && root[name] !== "") {
            return root[name]
        }
        return fallback !== undefined ? fallback : ""
    }

    // Returns the appropriate font family for the requested icon
    // Intelligently detects whether glyph is a Material Symbol ligature (ASCII text)
    // or a Nerd Font unicode glyph (PUA codepoint >= 0xE000).
    function effectiveFont(iconVal) {
        if (!iconVal || typeof iconVal !== "string") {
            return root.useMaterialSymbols ? root.symbolFont : root.iconFont
        }
        var cp = iconVal.codePointAt(0)
        // If it starts with ASCII lowercase letter or digit, it is a Material Symbol ligature
        if ((cp >= 97 && cp <= 122) || (cp >= 48 && cp <= 57)) {
            return root.symbolFont
        }
        // If it's a Unicode PUA symbol, it's a Nerd Font icon
        if (cp >= 0xE000) {
            return root.iconFont
        }
        return root.useMaterialSymbols ? root.symbolFont : root.iconFont
    }
}
