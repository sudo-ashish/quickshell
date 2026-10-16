//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "bar"
import "launcher"
import "osd"
import "notifications"
import "components"
import "polkit"
import "powermenu"

ShellRoot {
    id: root

    // Core Shared Services
    property WorkspacesService workspacesService: WorkspacesService { }
    property AudioService audioService: AudioService { }
    property BrightnessService brightnessService: BrightnessService { }
    property BatteryService batteryService: BatteryService { }
    property NetworkService networkService: NetworkService { }
    property BluetoothService bluetoothService: BluetoothService { }
    property PowerService powerService: PowerService { }
    property ThemeSwitcherService themeSwitcherService: ThemeSwitcherService { }
    property WallpaperSwitcherService wallpaperSwitcherService: WallpaperSwitcherService { }

    IpcHandler {
        target: "powerconfirm"
        function test(): string {
            root.powerService.requestShutdown(null)
            return "ok"
        }
        function cancel(): string {
            root.powerService.cancelConfirm()
            return "ok"
        }
    }

    // App Launcher (Rofi-style Quickshell application launcher)
    AppLauncher {
        id: launcher
    }

    // Power Confirmation Dialog (centered overlay)
    PowerConfirmDialog {
        id: powerConfirm
        powerService: root.powerService
    }

    // Bottom Pop-up Unified Menu (Power Session + Theme Switcher + Wallpaper Switcher)
    PowerMenu {
        id: bottomMenu
        powerService: root.powerService
        themeService: root.themeSwitcherService
        wallpaperService: root.wallpaperSwitcherService
    }

    // Polkit Authentication Agent (centered overlay)
    Polkit {
        id: polkit
    }

    // On-Screen Display (OSD UI Window)
    Osd {
        id: osd
        bluetoothService: root.bluetoothService
        brightnessService: root.brightnessService
    }

    // OSD IPC & Trigger Service (modeled on swayosd-client)
    OsdService {
        id: osdService
        osd: osd
    }

    // Desktop Notifications Service
    Notifications {
        id: notifications
    }

    // Mount Bar on each screen
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData

            workspacesService: root.workspacesService
            audioService: root.audioService
            brightnessService: root.brightnessService
            batteryService: root.batteryService
            networkService: root.networkService
            bluetoothService: root.bluetoothService
            powerService: root.powerService
        }
    }
}
