import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import "../services"

Item {
    id: root

    required property BatteryService batteryService
    required property PowerService powerService

    property bool showPercentage: Appearance.batteryShowPercentage
    property int iconSize: Appearance.batteryIconSize

    implicitWidth: batButton.implicitWidth
    implicitHeight: batButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: batButton
        icon: root.batteryService.icon
        iconSize: root.iconSize
        text: root.showPercentage ? (root.batteryService.capacity + "%") : ""
        accentActive: root.batteryService.isCharging
        customColor: {
            if (root.batteryService.isCharging) return Theme.accent
            if (root.batteryService.capacity <= 20) return Theme.red
            if (root.batteryService.capacity <= 40) return Theme.yellow
            return Theme.foreground
        }
        active: batPopup.open
        onClicked: {
            root.toggle()
        }
    }

    function toggle() {
        batPopup.toggle()
        if (batPopup.open) root.batteryService.refresh()
    }

    PopupCard {
        id: batPopup
        anchorItem: batButton
        showDefaultHeader: false
        contentWidth: 360
        contentHeight: 225

        Column {
            anchors.fill: parent
            spacing: 12

            // Top Banner: Battery icon + title + status, and percentage
            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: root.batteryService.icon
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 30
                        color: {
                            if (root.batteryService.isCharging) return Theme.accent
                            if (root.batteryService.capacity <= 20) return Theme.red
                            if (root.batteryService.capacity <= 40) return Theme.yellow
                            return Theme.foreground
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Battery"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeLarge
                            font.bold: true
                            color: Theme.foreground
                        }

                        Text {
                            text: root.batteryService.statusDisplay
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            color: root.batteryService.isCharging ? Theme.accent : Theme.muted
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryService.capacity + "%"
                    font.family: Fonts.monoFont
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.foreground
                }
            }

            // Wide Battery Progress Bar (Capsule)
            Rectangle {
                width: parent.width
                height: 8
                radius: Appearance.radiusSmall
                color: Theme.selection

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(8, Math.min(parent.width, parent.width * (root.batteryService.capacity / 100.0)))
                    radius: 4
                    color: {
                        if (root.batteryService.capacity <= 20) return Theme.red
                        if (root.batteryService.capacity <= 40) return Theme.yellow
                        if (root.batteryService.isCharging) return Theme.accent
                        return Theme.foreground
                    }
                }
            }

            // Stats 2-Column Grid (Battery size, Charge cycles, Time to full, Charging)
            Row {
                width: parent.width
                spacing: 16

                readonly property real colWidth: (width - spacing) / 2

                // Left Column
                Column {
                    width: parent.colWidth
                    spacing: 6

                    // Battery size
                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Battery size"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batteryService.batterySize
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: Theme.foreground
                        }
                    }

                    // Charge cycles
                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Charge cycles"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batteryService.cycleCount
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: Theme.foreground
                        }
                    }
                }

                // Right Column
                Column {
                    width: parent.colWidth
                    spacing: 6

                    // Time to full (or Time to empty)
                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batteryService.timeLabel
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batteryService.timeToFull
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: Theme.foreground
                        }
                    }

                    // Charging rate
                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Charging"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batteryService.chargingRate
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: Theme.foreground
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
            }

            // Power Profile Section Header
            Text {
                text: "POWER PROFILE"
                font.family: Fonts.uiFont
                font.pixelSize: 10
                font.bold: true
                color: Theme.muted
            }

            // Power Profiles Row (Power-saver, Balanced, Performance)
            Row {
                width: parent.width
                spacing: 8

                readonly property var profiles: [
                    { id: "power-saver", label: "Power-saver", icon: "󰌪" },
                    { id: "balanced", label: "Balanced", icon: "󰾆" },
                    { id: "performance", label: "Performance", icon: "󰓅" }
                ]

                Repeater {
                    model: parent.profiles

                    Rectangle {
                        id: profBtn
                        required property var modelData
                        width: (parent.width - 16) / 3
                        height: 38
                        radius: Appearance.radiusSmall

                        readonly property bool isActive: root.powerService.activeProfile === modelData.id

                        color: {
                            if (isActive) return Theme.selection
                            if (profMouse.containsMouse) return Theme.lighter_background
                            return Theme.dark_background
                        }

                        border.color: isActive ? Theme.accent : Theme.selection
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: profBtn.modelData.icon
                                font.family: Icons.effectiveFont(profBtn.modelData.icon)
                                font.pixelSize: Fonts.sizeRegular
                                color: profBtn.isActive ? Theme.accent : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: profBtn.modelData.label
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: profBtn.isActive 
                                color: profBtn.isActive ? Theme.accent : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: profMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerService.setProfile(profBtn.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
