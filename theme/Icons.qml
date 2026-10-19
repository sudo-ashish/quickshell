pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // =========================================================================
    // Icon Font Configurations
    // =========================================================================
    // Active icon font family. Defaults to Fonts.iconFont ("JetBrainsMono Nerd Font")
    property string iconFont: Fonts.iconFont

    // Alternate symbol font family (e.g. Google Material Symbols Rounded)
    property string symbolFont: Fonts.symbolFont

    // Switch between Nerd Font glyphs (default, false) and Material Symbols ligatures (true)
    property bool useMaterialSymbols: false

    // Local font loader for Google Material Symbols Rounded font
    property FontLoader materialSymbolsLoader: FontLoader {
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/MaterialSymbolsRounded.ttf"
    }

    // =========================================================================
    // Semantic Icon Sizes (Reactively scaled from typography tokens)
    // =========================================================================
    readonly property int sizeXs: Fonts.sizeXs         // ~9-10px
    readonly property int sizeSmall: Fonts.sizeSmall   // ~11-12px
    readonly property int sizeNormal: Fonts.sizeLarge  // ~16px
    readonly property int sizeMedium: Fonts.sizeTitle  // ~20-22px
    readonly property int sizeLarge: Fonts.sizeDisplay // ~26-28px
    readonly property int sizeDisplay: Fonts.sizeHero  // ~32-34px
    readonly property int sizeHero: Fonts.sizeGiant    // ~38px

    // =========================================================================
    // Semantic Icon Glyphs
    // =========================================================================
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

    // Hardware & Status
    readonly property string brightness: root.useMaterialSymbols ? "brightness_high" : "󰃠"
    readonly property string display: root.useMaterialSymbols ? "monitor" : "󰍹"
    readonly property string batteryFull: root.useMaterialSymbols ? "battery_full" : "󰁹"
    readonly property string batteryCharging: root.useMaterialSymbols ? "battery_charging_full" : "󰂄"
    readonly property string batteryLow: root.useMaterialSymbols ? "battery_alert" : "󰂃"
    readonly property string bluetooth: root.useMaterialSymbols ? "bluetooth" : "󰂯"
    readonly property string bluetoothConnected: root.useMaterialSymbols ? "bluetooth_connected" : "󰂱"
    readonly property string bluetoothDisconnected: root.useMaterialSymbols ? "bluetooth_disabled" : "󰂲"
    readonly property string wifi: root.useMaterialSymbols ? "wifi" : "󰤨"
    readonly property string wifiOff: root.useMaterialSymbols ? "wifi_off" : "󰤭"
    readonly property string ethernet: root.useMaterialSymbols ? "lan" : "󰈀"
    readonly property string bell: root.useMaterialSymbols ? "notifications" : "󰂚"
    readonly property string bellOff: root.useMaterialSymbols ? "notifications_off" : "󰂛"
    readonly property string calendar: root.useMaterialSymbols ? "calendar_month" : "󰃭"
    readonly property string clock: root.useMaterialSymbols ? "schedule" : "󰥔"
    readonly property string keyboard: root.useMaterialSymbols ? "keyboard" : "󰌌"
    readonly property string numlock: root.useMaterialSymbols ? "pin" : "󰎠"
    readonly property string trackpad: root.useMaterialSymbols ? "touchpad" : "󰟸"
    readonly property string trackpadOff: root.useMaterialSymbols ? "touchpad_off" : "󰤳"

    // Applications & UI
    readonly property string apps: root.useMaterialSymbols ? "apps" : "󰀻"
    readonly property string window: root.useMaterialSymbols ? "window" : "󰖲"
    readonly property string folder: root.useMaterialSymbols ? "folder" : "󰉋"
    readonly property string terminal: root.useMaterialSymbols ? "terminal" : "󰆍"
    readonly property string palette: root.useMaterialSymbols ? "palette" : "󰏘"
    readonly property string wallpaper: root.useMaterialSymbols ? "wallpaper" : "󰋩"

    // Helper function to safely resolve an icon by semantic name with a fallback
    function get(name, fallback) {
        if (root[name] !== undefined && root[name] !== "") {
            return root[name]
        }
        return fallback !== undefined ? fallback : ""
    }

    // Returns the appropriate font family for the requested icon
    function effectiveFont(iconVal) {
        if (root.useMaterialSymbols) return root.symbolFont
        return root.iconFont
    }
}
