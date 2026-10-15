function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

var widestIcon = "󰕾";

function iconFor(name, percent) {
    var n = String(name || "").toLowerCase();
    if (n === "volume-muted" || n === "volume-mute" || n === "muted" || n === "mute" || n === "󰝟" || n === "") return "󰝟";
    if (n === "volume-low" || n === "󰕿" || n === "") return "󰕿";
    if (n === "volume-medium" || n === "󰖀" || n === "") return "󰖀";
    if (n === "volume-high" || n === "󰕾" || n === "") return "󰕾";
    if (n === "headphones" || n === "headphone" || n === "headset" || n === "󰋋") return "󰋋";
    if (n === "volume" || n === "audio") {
        if (percent <= 0) return "󰝟";
        if (percent < 33) return "󰕿";
        if (percent < 66) return "󰖀";
        return "󰕾";
    }
    if (n === "microphone-muted" || n === "microphone-off" || n === "mic-muted" || n === "mic-off") return "󰍭";
    if (n === "microphone" || n === "mic") return "󰍬";
    if (n === "brightness" || n === "display" || n === "backlight") {
        if (percent < 33) return "󰃞";
        if (percent < 66) return "󰃟";
        return "󰃠";
    }

    // Bluetooth Device Events
    if (n === "bluetooth-connected" || n === "bt-connected") return "󰂱";
    if (n === "bluetooth-disconnected" || n === "bt-disconnected") return "󰂲";
    if (n === "bluetooth" || n === "bluetooth-on" || n === "bt") return "󰂯";

    // Num Lock & Keyboard Lock States
    if (n === "numlock-on" || n === "num-lock-on" || n === "numlock" || n === "num-lock") return "󰎠";
    if (n === "numlock-off" || n === "num-lock-off") return "󰎠";
    if (n === "capslock-on" || n === "caps-lock-on" || n === "capslock" || n === "caps-lock") return "󰌌";
    if (n === "capslock-off" || n === "caps-lock-off") return "󰌌";

    // Trackpad / Touchpad State
    if (n === "trackpad-on" || n === "touchpad-on" || n === "trackpad" || n === "touchpad") return "󰟸";
    if (n === "trackpad-off" || n === "touchpad-off") return "󰤳";

    // Monitor / Display Refresh Rate
    if (n === "monitor" || n === "screen" || n === "display-mode" || n === "refresh-rate" || n === "hz") return "󰍹";

    if (n === "touch" || n === "touchscreen") return "󰝁";
    if (n === "reboot" || n === "restart") return "󰜉";
    if (n === "shutdown" || n === "power" || n === "poweroff") return "󰐥";
    if (n === "logout" || n === "sign-out" || n === "leave") return "󰍃";
    if (n === "media" || n === "player") return "󰝚";
    if (n === "media-play" || n === "player-play") return "󰐊";
    if (n === "media-pause" || n === "player-pause") return "󰏤";
    if (n === "media-next" || n === "player-next") return "󰒭";
    if (n === "media-previous" || n === "player-previous") return "󰒮";

    // If icon is already a character/glyph or unknown name, return it if non-empty
    if (n.length > 0 && n !== "default") return name;

    // Fallback based on percentage
    if (percent <= 0) return "󰝟";
    if (percent <= 33) return "󰕿";
    if (percent <= 66) return "󰖀";
    return "󰕾";
}

function stateForShow(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration) {
    var maxValue = Math.max(1, parseInt(rawMax || "100", 10));
    var parsedValue = parseInt(rawValue !== undefined && rawValue !== null && rawValue !== "" ? rawValue : "-1", 10);
    var hasProgress = (rawValue !== undefined && rawValue !== null && rawValue !== "") && !isNaN(parsedValue) && parsedValue >= 0;
    var value = hasProgress ? clamp(parsedValue, 0, maxValue) : 0;
    var percent = hasProgress ? Math.round(value * 100 / maxValue) : -1;
    var parsedDuration = parseInt(rawDuration || "1600", 10);

    return {
        iconKey: String(iconName || "").toLowerCase(),
        maxValue: maxValue,
        hasProgress: hasProgress,
        value: value,
        message: String(rawMessage !== undefined && rawMessage !== null && rawMessage !== "" ? rawMessage : (hasProgress ? (rawProgressText || percent + "%") : "")),
        icon: iconFor(iconName, percent),
        duration: isNaN(parsedDuration) ? 1600 : Math.max(0, parsedDuration)
    };
}
