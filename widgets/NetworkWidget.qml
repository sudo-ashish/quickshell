import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import "../services"

Item {
    id: root

    required property NetworkService service

    property string selectedSsid: ""
    property bool showPasswordInput: false
    property bool showQrView: false
    property int iconSize: Appearance.networkIconSize

    implicitWidth: netButton.implicitWidth
    implicitHeight: netButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: netButton
        icon: root.service.icon
        iconSize: root.iconSize
        accentActive: root.service.wifiEnabled && root.service.currentSsid !== ""
        active: netPopup.open
        onClicked: {
            root.toggle()
        }
    }

    function toggle() {
        netPopup.toggle()
        if (netPopup.open) {
            root.service.refresh()
            root.service.scanWifi()
            root.showPasswordInput = false
            root.showQrView = false
        }
    }

    PopupCard {
        id: netPopup
        anchorItem: netButton
        showDefaultHeader: false
        contentWidth: 360
        contentHeight: root.showQrView ? 420 : 450

        Column {
            anchors.fill: parent
            spacing: 12

            // ================= 1. HEADER ROW =================
            Item {
                width: parent.width
                height: 42

                // Left: Wi-Fi Icon + SSID + Phrase
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: root.service.icon
                        font.family: Icons.effectiveFont(root.service.icon)
                        font.pixelSize: 26
                        color: Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: {
                                if (!root.service.wifiEnabled) return "Wi-Fi Off"
                                if (root.service.connectingSsid) return root.service.connectingSsid
                                return root.service.currentSsid || "Not Connected"
                            }
                            font.family: Fonts.uiFont
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.foreground
                            elide: Text.ElideRight
                            width: 140
                        }

                        Text {
                            text: {
                                if (!root.service.wifiEnabled) return "DISABLED"
                                if (root.service.connectingSsid) return "CONNECTING..."
                                if (root.service.currentSsid) return root.service.connectionPhrase
                                return "DISCONNECTED"
                            }
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            color: root.service.connectingSsid ? Theme.accent : Theme.muted
                        }
                    }
                }

                // Right Actions: QR, Quick Disconnect, Toggle Switch
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Quick Disconnect Button (visible when connected)
                    Rectangle {
                        visible: root.service.wifiEnabled && root.service.currentSsid !== ""
                        width: 28
                        height: 28
                        radius: Appearance.radiusSmall
                        color: topDisMouse.containsMouse ? Theme.darker_background : Theme.dark_background
                        border.color: topDisMouse.containsMouse ? Theme.red : Theme.selection
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰌙"
                            font.family: Icons.effectiveFont("󰌙")
                            font.pixelSize: 14
                            color: topDisMouse.containsMouse ? Theme.red : Theme.muted
                        }

                        MouseArea {
                            id: topDisMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.disconnectNetwork(root.service.currentSsid)
                        }
                    }

                    // QR Code Button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: Appearance.radiusSmall
                        color: root.showQrView ? Theme.selection : (qrMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)
                        border.color: root.showQrView ? Theme.accent : Theme.selection
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰐲"
                            font.family: Icons.effectiveFont("󰐲")
                            font.pixelSize: 16
                            color: root.showQrView ? Theme.accent : Theme.foreground
                        }

                        MouseArea {
                            id: qrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.showQrView = !root.showQrView
                                if (root.showQrView) {
                                    root.service.generateQr()
                                }
                            }
                        }
                    }

                    // Wi-Fi On/Off Rectangular Toggle Switch
                    ToggleSwitch {
                        id: wifiToggle
                        checked: root.service.wifiEnabled
                        onToggled: root.service.toggleWifi()
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.selection
            }

            // ================= QR CODE OVERLAY VIEW =================
            Item {
                visible: root.showQrView
                width: parent.width
                height: root.showQrView ? 340 : 0

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Scan to Join Wi-Fi"
                        font.family: Fonts.uiFont
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.foreground
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // QR Matrix Canvas Container
                    Rectangle {
                        id: qrBox
                        width: 210
                        height: 210
                        color: Theme.bright_foreground
                        radius: Appearance.radiusSmall
                        anchors.horizontalCenter: parent.horizontalCenter

                        readonly property int size: root.service.qrSize > 0 ? root.service.qrSize : 1
                        readonly property real cellSize: size > 0 ? (width / size) : 0

                        Grid {
                            anchors.fill: parent
                            columns: qrBox.size

                            Repeater {
                                model: qrBox.size * qrBox.size

                                Rectangle {
                                    required property int index
                                    readonly property int r: Math.floor(index / qrBox.size)
                                    readonly property int c: index % qrBox.size

                                    width: qrBox.cellSize
                                    height: qrBox.cellSize
                                    color: (root.service.qrMatrix.length > r && root.service.qrMatrix[r].charAt(c) === "1") ? Theme.darker_background : "transparent"
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.service.qrLoading
                            text: "Generating QR..."
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.darker_background
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.service.qrLoading && root.service.qrSize === 0
                            text: root.service.qrError || "No QR available"
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            color: Theme.red
                        }
                    }

                    Text {
                        text: "SSID: " + root.service.currentSsid
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        color: Theme.muted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 80
                        height: 26
                        radius: Appearance.radiusSmall
                        color: Theme.dark_background
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "Close"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.foreground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showQrView = false
                        }
                    }
                }
            }

            // ================= MAIN NETWORK CONTENT =================
            Column {
                visible: !root.showQrView
                width: parent.width
                spacing: 12

                // --- 2. DNS PROVIDER Section (Segmented Buttons) ---
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "DNS PROVIDER"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Row {
                        id: dnsRow
                        width: parent.width
                        spacing: 5

                        readonly property int count: root.service.dnsProviders.length
                        readonly property real cellWidth: (width - (spacing * (count - 1))) / count

                        Repeater {
                            model: root.service.dnsProviders

                            Rectangle {
                                id: dnsPill
                                required property string modelData
                                required property int index

                                readonly property bool isActive: (root.service.dnsProvider === modelData)

                                width: dnsRow.cellWidth
                                height: 28
                                radius: Appearance.radiusSmall
                                color: isActive ? Theme.selection : (dnsMouse.containsMouse ? Theme.lighter_background : Theme.dark_background)
                                border.color: isActive ? Theme.accent : (dnsMouse.containsMouse ? Theme.muted : Theme.selection)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: dnsPill.modelData
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.bold: dnsPill.isActive 
                                    color: Theme.foreground
                                }

                                MouseArea {
                                    id: dnsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.service.setDns(dnsPill.modelData)
                                }
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

                // --- Password Input Overlay (if joining a secured network) ---
                Rectangle {
                    visible: root.showPasswordInput
                    width: parent.width
                    height: root.showPasswordInput ? 72 : 0
                    radius: Appearance.radiusSmall
                    color: Theme.lighter_background
                    border.color: Theme.accent
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Text {
                            text: "Connect to: " + root.selectedSsid
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.accent
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width - 130
                                height: 28
                                radius: Appearance.radiusSmall
                                color: Theme.dark_background
                                border.color: Theme.selection

                                TextInput {
                                    id: pwInput
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    echoMode: TextInput.Password
                                    font.family: Fonts.monoFont
                                    font.pixelSize: 11
                                    color: Theme.foreground
                                    clip: true
                                    onAccepted: joinBtn.join()
                                }
                            }

                            Rectangle {
                                id: joinBtn
                                readonly property bool isJoining: root.service.connectingSsid === root.selectedSsid
                                width: isJoining ? 70 : 56
                                height: 28
                                radius: Appearance.radiusSmall
                                color: Theme.accent

                                function join() {
                                    if (joinBtn.isJoining) return
                                    root.service.connectToNetwork(root.selectedSsid, pwInput.text)
                                    root.showPasswordInput = false
                                    pwInput.text = ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: joinBtn.isJoining ? "Joining…" : "Join"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.bright_foreground
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !joinBtn.isJoining
                                    cursorShape: joinBtn.isJoining ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: joinBtn.join()
                                }
                            }

                            Rectangle {
                                width: 56
                                height: 28
                                radius: Appearance.radiusSmall
                                color: Theme.dark_background

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showPasswordInput = false
                                        pwInput.text = ""
                                    }
                                }
                            }
                        }
                    }
                }

                // --- 3. KNOWN NETWORKS Section ---
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.service.knownNetworks.length > 0

                    Text {
                        text: "KNOWN NETWORKS"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Repeater {
                        model: root.service.knownNetworks

                        Rectangle {
                            id: knownRow
                            required property var modelData
                            required property int index

                            readonly property bool isConnected: modelData.active
                            readonly property bool isSelected: root.selectedSsid === modelData.ssid
                            readonly property bool isConnecting: root.service.connectingSsid === modelData.ssid
                            readonly property bool hasError: root.service.connectionErrorSsid === modelData.ssid

                            width: parent.width
                            height: 42
                            radius: Appearance.radiusSmall
                            color: isConnected ? Theme.selection : (isSelected || isConnecting ? Theme.selection : (kMouse.containsMouse ? Theme.lighter_background : "transparent"))
                            border.color: isConnected ? Theme.accent : (isSelected || isConnecting ? Theme.selection : "transparent")
                            border.width: (isConnected || isSelected || isConnecting) ? 1 : 0

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Text {
                                    text: root.service.wifiIconFor(knownRow.modelData.signal)
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 16
                                    color: (knownRow.isConnected || knownRow.isConnecting) ? Theme.accent : Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: knownRow.modelData.ssid
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        font.bold: knownRow.isConnected 
                                        color: Theme.foreground
                                        elide: Text.ElideRight
                                        width: 115
                                    }

                                    Text {
                                        text: knownRow.isConnecting ? "Connecting..." : (knownRow.hasError ? root.service.connectionErrorMessage : (knownRow.isConnected ? "Connected" : "Saved"))
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 10
                                        color: knownRow.isConnecting ? Theme.accent : (knownRow.hasError ? Theme.red : (knownRow.isConnected ? Theme.accent : Theme.muted))
                                    }
                                }
                            }

                            // Right Actions: Lock Icon + Connect/Disconnect + Forget
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                // Lock icon
                                Text {
                                    visible: knownRow.modelData.isSecured
                                    text: "󰌾"
                                    font.family: Icons.effectiveFont("󰌾")
                                    font.pixelSize: 12
                                    color: Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Connect / Disconnect Button
                                Rectangle {
                                    id: connBtn
                                    width: knownRow.isConnecting ? 76 : (knownRow.isConnected ? 68 : 54)
                                    height: 24
                                    radius: Appearance.radiusSmall
                                    color: knownRow.isConnecting ? Theme.selection : (knownRow.isConnected ? (connMouse.containsMouse ? Theme.darker_background : Theme.dark_background) : (connMouse.containsMouse ? Theme.selection : Theme.dark_background))
                                    border.color: knownRow.isConnecting ? Theme.accent : (knownRow.isConnected ? (connMouse.containsMouse ? Theme.red : Theme.selection) : (connMouse.containsMouse ? Theme.accent : Theme.selection))
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: knownRow.isConnecting ? "Connecting…" : (knownRow.isConnected ? "Disconnect" : "Connect")
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: knownRow.isConnecting ? Theme.accent : (knownRow.isConnected ? (connMouse.containsMouse ? Theme.red : Theme.foreground) : (connMouse.containsMouse ? Theme.accent : Theme.foreground))
                                    }

                                    MouseArea {
                                        id: connMouse
                                        anchors.fill: parent
                                        enabled: !knownRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: knownRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedSsid = knownRow.modelData.ssid
                                            if (knownRow.isConnected) {
                                                root.service.disconnectNetwork(knownRow.modelData.ssid)
                                            } else {
                                                root.service.connectToNetwork(knownRow.modelData.ssid, "")
                                            }
                                        }
                                    }
                                }

                                // Forget Button
                                Rectangle {
                                    id: fgtBtn
                                    width: 48
                                    height: 24
                                    radius: Appearance.radiusSmall
                                    color: fgtMouse.containsMouse ? Theme.darker_background : Theme.dark_background
                                    border.color: fgtMouse.containsMouse ? Theme.red : Theme.selection
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Forget"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: fgtMouse.containsMouse ? Theme.red : Theme.muted
                                    }

                                    MouseArea {
                                        id: fgtMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedSsid = knownRow.modelData.ssid
                                            root.service.forgetNetwork(knownRow.modelData.ssid)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: kMouse
                                anchors.fill: parent
                                anchors.rightMargin: knownRow.isConnecting ? 155 : 135
                                enabled: !knownRow.isConnecting
                                hoverEnabled: true
                                cursorShape: knownRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedSsid = knownRow.modelData.ssid
                                    if (!knownRow.isConnected) {
                                        root.service.connectToNetwork(knownRow.modelData.ssid, "")
                                    }
                                }
                            }
                        }
                    }
                }

                // --- 4. OTHER NETWORKS Section ---
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.service.otherNetworks.length > 0

                    Text {
                        text: "OTHER NETWORKS"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    // Scrollable list for other networks
                    Rectangle {
                        width: parent.width
                        height: Math.min(140, root.service.otherNetworks.length * 36)
                        color: "transparent"
                        clip: true

                        ListView {
                            id: otherList
                            anchors.fill: parent
                            spacing: 2
                            model: root.service.otherNetworks
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: otherRow
                                required property var modelData
                                required property int index
                                readonly property bool isConnecting: root.service.connectingSsid === modelData.ssid
                                readonly property bool hasError: root.service.connectionErrorSsid === modelData.ssid

                                width: otherList.width
                                height: (isConnecting || hasError) ? 40 : 34
                                radius: Appearance.radiusSmall
                                color: isConnecting ? Theme.selection : (oMouse.containsMouse ? Theme.lighter_background : "transparent")
                                border.color: isConnecting ? Theme.selection : "transparent"
                                border.width: isConnecting ? 1 : 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    Text {
                                        text: root.service.wifiIconFor(otherRow.modelData.signal)
                                        font.family: Icons.effectiveFont(text)
                                        font.pixelSize: 16
                                        color: otherRow.isConnecting ? Theme.accent : Theme.foreground
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: otherRow.modelData.ssid
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 12
                                            color: Theme.foreground
                                            font.bold: otherRow.modelData.active 
                                            elide: Text.ElideRight
                                            width: (otherRow.isConnecting || otherRow.hasError) ? 140 : 170
                                        }

                                        Text {
                                            visible: otherRow.isConnecting || otherRow.hasError
                                            text: otherRow.isConnecting ? "Connecting..." : (otherRow.hasError ? root.service.connectionErrorMessage : "")
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 9
                                            color: otherRow.isConnecting ? Theme.accent : Theme.red
                                        }
                                    }
                                }

                                // Right Actions: Lock Icon + Connect Button
                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    // Lock icon
                                    Text {
                                        visible: otherRow.modelData.isSecured
                                        text: "󰌾"
                                        font.family: Icons.effectiveFont("󰌾")
                                        font.pixelSize: 12
                                        color: Theme.muted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Connect Button
                                    Rectangle {
                                        width: otherRow.isConnecting ? 76 : 54
                                        height: 24
                                        radius: Appearance.radiusSmall
                                        color: otherRow.isConnecting ? Theme.selection : (oConnMouse.containsMouse ? Theme.selection : Theme.dark_background)
                                        border.color: otherRow.isConnecting ? Theme.accent : (oConnMouse.containsMouse ? Theme.accent : Theme.selection)
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: otherRow.isConnecting ? "Connecting…" : "Connect"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: (otherRow.isConnecting || oConnMouse.containsMouse) ? Theme.accent : Theme.foreground
                                        }

                                        MouseArea {
                                            id: oConnMouse
                                            anchors.fill: parent
                                            enabled: !otherRow.isConnecting
                                            hoverEnabled: true
                                            cursorShape: otherRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                root.selectedSsid = otherRow.modelData.ssid
                                                if (otherRow.modelData.isSecured) {
                                                    root.showPasswordInput = true
                                                } else {
                                                    root.service.connectToNetwork(root.selectedSsid, "")
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: oMouse
                                    anchors.fill: parent
                                    anchors.rightMargin: otherRow.isConnecting ? 88 : 65
                                    enabled: !otherRow.isConnecting
                                    hoverEnabled: true
                                    cursorShape: otherRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedSsid = otherRow.modelData.ssid
                                        if (otherRow.modelData.isSecured) {
                                            root.showPasswordInput = true
                                        } else {
                                            root.service.connectToNetwork(root.selectedSsid, "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
