import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../theme"
import "../components"
import "../services"

Item {
    id: root

    required property BluetoothService service

    property int iconSize: Appearance.bluetoothIconSize

    implicitWidth: btButton.implicitWidth
    implicitHeight: btButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function toggle() {
        btPopup.toggle()
        if (btPopup.open) {
            root.service.refresh()
            if (root.service.bluetoothEnabled) root.service.scan()
        }
    }

    BarButton {
        id: btButton
        icon: root.service.icon
        iconSize: root.iconSize
        accentActive: root.service.connectedDevices.length > 0
        customColor: root.service.bluetoothEnabled ? (root.service.connectedDevices.length > 0 ? Theme.accent : Theme.foreground) : Theme.muted
        active: btPopup.open
        onClicked: {
            btPopup.toggle()
            if (btPopup.open) {
                root.service.refresh()
                if (root.service.bluetoothEnabled) {
                    root.service.scan()
                }
            }
        }
    }

    Connections {
        target: root.service
        function onRequestToggleMenu() {
            btPopup.toggle()
            if (btPopup.open) {
                root.service.refresh()
                if (root.service.bluetoothEnabled) {
                    root.service.scan()
                }
            }
        }
    }

    PopupCard {
        id: btPopup
        anchorItem: btButton
        showDefaultHeader: false
        contentWidth: 330
        contentHeight: root.service.bluetoothEnabled ? 340 : 110

        Binding {
            target: root.service
            property: "menuOpen"
            value: btPopup.open
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // ── Hero Header ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.service.connectedDevices.length > 0 ? "󰂱" : (root.service.bluetoothEnabled ? "󰂯" : "󰂲")
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 22
                    color: root.service.bluetoothEnabled ? Theme.accent : Theme.muted
                    opacity: root.service.bluetoothEnabled ? 1.0 : 0.6
                    Layout.alignment: Qt.AlignVCenter
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: "Bluetooth"
                        font.family: Fonts.uiFont
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.foreground
                    }

                    Text {
                        text: root.service.heroSubtitle
                        font.family: Fonts.uiFont
                        font.pixelSize: 9
                        font.bold: true
                        color: Theme.muted
                    }
                }

                ToggleSwitch {
                    Layout.alignment: Qt.AlignVCenter
                    checked: root.service.bluetoothEnabled
                    onToggled: root.service.togglePower()
                }
            }

            // ── Header Divider ────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.selection
            }

            // ── Bluetooth Turned Off Message ──────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.service.bluetoothEnabled

                Text {
                    anchors.centerIn: parent
                    text: "Turn Bluetooth on to scan"
                    font.family: Fonts.uiFont
                    font.pixelSize: 11
                    color: Theme.muted
                }
            }

            // ── Enabled Content Container ─────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.service.bluetoothEnabled

                ScrollView {
                    anchors.fill: parent
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        width: parent.width
                        spacing: 10

                        // ── Connected Devices Section ─────────────────
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.service.connectedDevices.length > 0

                            Text {
                                text: "CONNECTED"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.muted
                            }

                            Repeater {
                                model: root.service.connectedDevices

                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 44
                                    radius: Appearance.radiusSmall
                                    color: Theme.selection
                                    border.color: Theme.selection
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 10

                                        Text {
                                            text: "󰂱"
                                            font.family: Icons.effectiveFont("󰂱")
                                            font.pixelSize: 16
                                            color: Theme.accent
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: Theme.foreground
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.battery || "Connected"
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 9
                                                color: Theme.muted
                                            }
                                        }

                                        // Disconnect Button
                                        Rectangle {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: Appearance.radiusSmall
                                            color: disMouse.containsMouse ? Theme.darker_background : Theme.dark_background
                                            border.color: disMouse.containsMouse ? Theme.red : Theme.selection
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅙"
                                                font.family: Icons.effectiveFont("󰅙")
                                                font.pixelSize: 12
                                                color: disMouse.containsMouse ? Theme.red : Theme.muted
                                            }

                                            MouseArea {
                                                id: disMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.service.disconnectDevice(modelData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Divider after Connected
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.selection
                            visible: root.service.connectedDevices.length > 0 && (root.service.pairedDevices.length > 0 || root.service.availableDevices.length > 0)
                        }

                        // ── Saved Devices Section ────────────────────
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: root.service.pairedDevices.length > 0

                            Text {
                                text: "SAVED DEVICES"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.muted
                            }

                            Repeater {
                                model: root.service.pairedDevices

                                delegate: Rectangle {
                                    id: pairedRow
                                    required property var modelData
                                    readonly property bool isConnecting: root.service.connectingMac === modelData.mac
                                    readonly property bool hasError: root.service.actionErrorMac === modelData.mac

                                    width: parent.width
                                    height: 44
                                    radius: Appearance.radiusSmall
                                    color: isConnecting ? Theme.selection : (pMouse.containsMouse ? Theme.lighter_background : "transparent")
                                    border.color: isConnecting ? Theme.selection : "transparent"
                                    border.width: isConnecting ? 1 : 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 10

                                        Text {
                                            text: "󰂯"
                                            font.family: Icons.effectiveFont("󰂯")
                                            font.pixelSize: 14
                                            color: isConnecting ? Theme.accent : Theme.muted
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: Theme.foreground
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: pairedRow.isConnecting ? "Connecting..." : (pairedRow.hasError ? root.service.actionErrorMessage : "Offline")
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 9
                                                color: pairedRow.isConnecting ? Theme.accent : (pairedRow.hasError ? Theme.red : Theme.dark_foreground)
                                            }
                                        }

                                        // Connect Button
                                        Rectangle {
                                            id: connBtn
                                            Layout.preferredWidth: pairedRow.isConnecting ? 80 : 58
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: Appearance.radiusSmall
                                            color: pairedRow.isConnecting ? Theme.selection : (cMouse.containsMouse ? Theme.selection : Theme.dark_background)
                                            border.color: pairedRow.isConnecting ? Theme.accent : (cMouse.containsMouse ? Theme.accent : Theme.selection)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: pairedRow.isConnecting ? "Connecting…" : "Connect"
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: (pairedRow.isConnecting || cMouse.containsMouse) ? Theme.accent : Theme.foreground
                                            }

                                            MouseArea {
                                                id: cMouse
                                                anchors.fill: parent
                                                enabled: !pairedRow.isConnecting
                                                hoverEnabled: true
                                                cursorShape: pairedRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                onClicked: root.service.connectDevice(modelData.mac, true)
                                            }
                                        }

                                        // Forget Button
                                        Rectangle {
                                            id: forgetBtn
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: Appearance.radiusSmall
                                            color: forgetMouse.containsMouse ? Theme.darker_background : "transparent"
                                            border.color: forgetMouse.containsMouse ? Theme.red : "transparent"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅙"
                                                font.family: Icons.effectiveFont("󰅙")
                                                font.pixelSize: 12
                                                color: forgetMouse.containsMouse ? Theme.red : Theme.dark_foreground
                                            }

                                            MouseArea {
                                                id: forgetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.service.forgetDevice(modelData.mac)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: pMouse
                                        anchors.fill: parent
                                        anchors.rightMargin: pairedRow.isConnecting ? 112 : 90
                                        enabled: !pairedRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: pairedRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: root.service.connectDevice(modelData.mac, true)
                                    }
                                }
                            }
                        }

                        // Divider after Saved
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.selection
                            visible: root.service.pairedDevices.length > 0 && root.service.availableDevices.length > 0
                        }

                        // ── Available Devices Section ─────────────────
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: root.service.availableDevices.length > 0

                            Text {
                                text: "AVAILABLE DEVICES"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.muted
                            }

                            Repeater {
                                model: root.service.availableDevices

                                delegate: Rectangle {
                                    id: availRow
                                    required property var modelData
                                    readonly property bool isPairing: root.service.pairingMac === modelData.mac
                                    readonly property bool isConnecting: root.service.connectingMac === modelData.mac
                                    readonly property bool hasError: root.service.actionErrorMac === modelData.mac

                                    width: parent.width
                                    height: (isPairing || isConnecting || hasError) ? 44 : 36
                                    radius: Appearance.radiusSmall
                                    color: (isPairing || isConnecting) ? Theme.selection : (aMouse.containsMouse ? Theme.lighter_background : "transparent")
                                    border.color: (isPairing || isConnecting) ? Theme.selection : "transparent"
                                    border.width: (isPairing || isConnecting) ? 1 : 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 10

                                        Text {
                                            text: "󰂯"
                                            font.family: Icons.effectiveFont("󰂯")
                                            font.pixelSize: 14
                                            color: (isPairing || isConnecting) ? Theme.accent : Theme.dark_foreground
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 11
                                                color: Theme.foreground
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                visible: availRow.isPairing || availRow.isConnecting || availRow.hasError
                                                text: availRow.isPairing ? "Pairing..." : (availRow.isConnecting ? "Connecting..." : (availRow.hasError ? root.service.actionErrorMessage : ""))
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 9
                                                color: (availRow.isPairing || availRow.isConnecting) ? Theme.accent : Theme.red
                                            }
                                        }

                                        // Pair/Connect Button
                                        Rectangle {
                                            Layout.preferredWidth: (availRow.isPairing || availRow.isConnecting) ? 72 : 48
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: Appearance.radiusSmall
                                            color: (availRow.isPairing || availRow.isConnecting) ? Theme.selection : (pairMouse.containsMouse ? Theme.selection : Theme.dark_background)
                                            border.color: (availRow.isPairing || availRow.isConnecting) ? Theme.accent : (pairMouse.containsMouse ? Theme.accent : Theme.selection)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: availRow.isPairing ? "Pairing…" : (availRow.isConnecting ? "Connecting…" : "Pair")
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: (availRow.isPairing || availRow.isConnecting || pairMouse.containsMouse) ? Theme.accent : Theme.foreground
                                            }

                                            MouseArea {
                                                id: pairMouse
                                                anchors.fill: parent
                                                enabled: !availRow.isPairing && !availRow.isConnecting
                                                hoverEnabled: true
                                                cursorShape: (availRow.isPairing || availRow.isConnecting) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                onClicked: root.service.pairDevice(modelData.mac)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: aMouse
                                        anchors.fill: parent
                                        anchors.rightMargin: (availRow.isPairing || availRow.isConnecting) ? 80 : 58
                                        enabled: !availRow.isPairing && !availRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: (availRow.isPairing || availRow.isConnecting) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: root.service.pairDevice(modelData.mac)
                                    }
                                }
                            }
                        }

                        // Empty Scanning State
                        Item {
                            width: parent.width
                            height: 40
                            visible: root.service.connectedDevices.length === 0 && root.service.pairedDevices.length === 0 && root.service.availableDevices.length === 0

                            Text {
                                anchors.centerIn: parent
                                text: "Scanning for devices…"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.dark_foreground
                            }
                        }
                    }
                }
            }
        }
    }
}
