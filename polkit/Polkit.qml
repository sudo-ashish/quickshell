import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "PolkitModel.js" as PolkitModel

Item {
    id: root


    property bool closing: false
    property bool submitted: false
    property string currentMessage: ""
    property string currentPrompt: ""
    property string currentSupplementary: ""
    property bool responseRequired: false
    property bool responseVisible: false
    property bool failed: false
    property bool errorFlash: false
    property int shakeOffset: 0

    property bool testMode: false
    readonly property var polkitAgent: agentLoader.item
    readonly property bool dialogVisible: ((polkitAgent && polkitAgent.isActive) || closing || testMode)

    function authorizationLabel(message) {
        return PolkitModel.authorizationLabel(message)
    }

    function cleanPromptText(prompt) {
        var p = String(prompt || "").trim()
        if (!p) return "Enter password"
        if (p.endsWith(":")) p = p.slice(0, -1).trim()
        return p
    }

    function resetSnapshot() {
        currentMessage = ""
        currentPrompt = ""
        currentSupplementary = ""
        responseRequired = false
        responseVisible = false
        failed = false
        errorFlash = false
        submitted = false
        passwordInput.text = ""
    }

    function syncFromFlow() {
        var flow = polkitAgent ? polkitAgent.flow : null
        if (!flow) return

        currentMessage = String(flow.message || "Authentication is required")
        currentPrompt = String(flow.inputPrompt || "")
        currentSupplementary = String(flow.supplementaryMessage || "")
        responseRequired = !!flow.isResponseRequired
        responseVisible = !!flow.responseVisible
        failed = !!flow.failed

        if (responseRequired) submitted = false
    }

    function beginFlow() {
        closeTimer.stop()
        closing = false
        submitted = false
        errorFlash = false
        passwordInput.text = ""
        syncFromFlow()
        Qt.callLater(refocus)
    }

    function refocus() {
        if (!dialogVisible) return
        passwordInput.forceActiveFocus()
    }

    function submitResponse() {
        var flow = polkitAgent ? polkitAgent.flow : null
        if (!flow || !flow.isResponseRequired) return
        submitted = true
        errorFlash = false
        flow.submit(passwordInput.text)
        passwordInput.text = ""
    }

    function cancelRequest() {
        var flow = polkitAgent ? polkitAgent.flow : null
        passwordInput.text = ""
        submitted = false
        closing = true
        closeTimer.restart()
        if (flow) {
            try {
                flow.cancelAuthenticationRequest()
            } catch (e) {}
        }
    }

    function triggerFailureFeedback() {
        submitted = false
        errorFlash = true
        passwordInput.text = ""
        errorTimer.restart()
        shakeAnimation.restart()
    }

    Timer {
        id: closeTimer
        interval: 250
        repeat: false
        onTriggered: {
            closing = false
            resetSnapshot()
        }
    }

    Timer {
        id: errorTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.errorFlash = false
            Qt.callLater(root.refocus)
        }
    }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: root; property: "shakeOffset"; to: -10; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 10; duration: 55; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -6; duration: 45; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 6; duration: 45; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 50; easing.type: Easing.OutQuad }
    }

    // Agent Loader with automatic retry on registration contention
    Loader {
        id: agentLoader
        active: true
        sourceComponent: Component {
            PolkitAgent {
                id: agent
                path: "/org/quickshell/Polkit"

                onAuthenticationRequestStarted: root.beginFlow()
                onFlowChanged: {
                    if (flow) {
                        root.beginFlow()
                    }
                }
                onIsActiveChanged: {
                    if (isActive) root.syncFromFlow()
                    else if (!root.closing) root.resetSnapshot()
                }
                onIsRegisteredChanged: {
                    if (isRegistered) {
                        console.log("quickshell polkit agent registered successfully")
                    } else {
                        console.warn("quickshell polkit agent not registered; another agent may be holding the session")
                    }
                }
            }
        }
    }

    Timer {
        id: retryRegisterTimer
        interval: 3000
        repeat: true
        running: polkitAgent ? !polkitAgent.isRegistered : true
        onTriggered: {
            if (!polkitAgent || !polkitAgent.isRegistered) {
                console.log("Retrying quickshell polkit agent registration...")
                agentLoader.active = false
                agentLoader.active = true
            }
        }
    }

    Connections {
        target: polkitAgent ? polkitAgent.flow : null
        enabled: polkitAgent && polkitAgent.flow !== null
        ignoreUnknownSignals: true

        function onIsResponseRequiredChanged() {
            root.syncFromFlow()
            if (!polkitAgent || !polkitAgent.flow || !polkitAgent.flow.isResponseRequired) passwordInput.text = ""
            Qt.callLater(root.refocus)
        }

        function onInputPromptChanged() { root.syncFromFlow() }
        function onResponseVisibleChanged() { root.syncFromFlow() }
        function onSupplementaryMessageChanged() { root.syncFromFlow() }
        function onFailedChanged() { root.syncFromFlow() }

        function onAuthenticationFailed() {
            root.syncFromFlow()
            root.triggerFailureFeedback()
        }

        function onAuthenticationSucceeded() {
            root.closing = true
            closeTimer.restart()
        }

        function onAuthenticationRequestCancelled() {
            root.closing = true
            closeTimer.restart()
        }
    }

    PanelWindow {
        id: panel
        visible: root.dialogVisible
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        screen: {
            if (!Quickshell.screens || Quickshell.screens.length === 0) return null
            var foc = Hyprland.focusedMonitor
            if (foc && foc.name) {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === foc.name) {
                        return Quickshell.screens[i]
                    }
                }
            }
            return Quickshell.screens[0]
        }

        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.dialogVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)
            opacity: root.dialogVisible ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.refocus()
        }

        // Authentication Card
        Rectangle {
            id: card
            width: 420
            implicitHeight: cardLayout.implicitHeight + 40
            radius: Appearance.cardRadius
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.shakeOffset
            color: Theme.withAlpha(Theme.background, Theme.elevatedOpacity)
            border.color: root.errorFlash ? Theme.red : (passwordInput.activeFocus ? Theme.accent : Theme.selection)
            border.width: Appearance.borderWidthThin

            // Consume clicks inside card so scrim doesn't trigger
            MouseArea {
                anchors.fill: parent
                onClicked: root.refocus()
            }

            Item {
                id: keyCatcher
                anchors.fill: parent
                focus: true

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.cancelRequest()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.responseRequired && !root.submitted) root.submitResponse()
                        event.accepted = true
                    }
                }
            }

            ColumnLayout {
                id: cardLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Appearance.paddingXl
                spacing: Appearance.spacingLarge + 2

                // Header row with Icon and Label
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacingLarge

                    Rectangle {
                        width: 36
                        height: 36
                        radius: Appearance.radiusMedium
                        color: root.errorFlash ? Theme.red : Theme.selection

                        Text {
                            anchors.centerIn: parent
                            text: Icons.lock
                            color: root.errorFlash ? Theme.bright_red : Theme.accent
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.sizeLarge + 2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacingXs

                        Text {
                            Layout.fillWidth: true
                            text: root.authorizationLabel(root.currentMessage)
                            color: Theme.foreground
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeRegular
                            font.weight: Fonts.weightBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentSupplementary.length > 0 ? root.currentSupplementary : (root.currentMessage.length > 0 ? root.currentMessage : "Privileged action requires authentication")
                            color: root.errorFlash ? Theme.red : Theme.muted
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }

                // Password Input Box
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: Appearance.radiusMedium
                    color: Theme.withAlpha(Theme.darker_background, Theme.layerOpacity)
                    border.color: root.errorFlash ? Theme.red : (passwordInput.activeFocus ? Theme.accent : Theme.selection)
                    border.width: Appearance.borderWidthThin

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Appearance.spacingLarge
                        anchors.rightMargin: Appearance.spacingLarge
                        spacing: Appearance.spacingMedium

                        Text {
                            text: Icons.unlock
                            color: root.errorFlash ? Theme.red : (passwordInput.activeFocus ? Theme.accent : Theme.muted)
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.sizeLarge
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                activeFocusOnPress: true
                                clip: true
                                selectionColor: Theme.selection
                                selectedTextColor: Theme.bright_foreground
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeRegular
                                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                color: root.errorFlash ? Theme.red : Theme.foreground
                                cursorVisible: activeFocus && !root.submitted && !root.errorFlash
                                readOnly: root.submitted || root.errorFlash
                                enabled: root.dialogVisible
                                onAccepted: root.submitResponse()

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Escape) {
                                        root.cancelRequest()
                                        event.accepted = true
                                    }
                                }
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: {
                                    if (root.errorFlash) return "Authentication failed — please try again"
                                    if (root.submitted) return "Verifying password..."
                                    return root.cleanPromptText(root.currentPrompt)
                                }
                                color: root.errorFlash ? Theme.red : Theme.muted
                                opacity: root.errorFlash ? 1 : 0.6
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeRegular
                                elide: Text.ElideRight
                                visible: passwordInput.text.length === 0
                            }
                        }
                    }
                }

                // Action buttons: Cancel and Authenticate
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacingMedium + 2

                    Item { Layout.fillWidth: true }

                    // Cancel button
                    Rectangle {
                        width: 84
                        height: Appearance.buttonHeight
                        radius: Appearance.buttonRadius
                        color: cancelMouse.containsMouse ? Theme.lighter_background : Theme.selection
                        border.color: Theme.selection
                        border.width: Appearance.borderWidthThin

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            color: Theme.muted
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelRequest()
                        }
                    }

                    // Authenticate button
                    Rectangle {
                        width: 110
                        height: Appearance.buttonHeight
                        radius: Appearance.buttonRadius
                        color: authMouse.containsMouse ? Theme.bright_blue : Theme.accent
                        opacity: root.submitted ? 0.6 : 1.0

                        Row {
                            anchors.centerIn: parent
                            spacing: Appearance.spacingMedium - 2 // 6px

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.submitted ? Icons.spinner : Icons.check
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.sizeRegular
                                color: Theme.darker_background
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.submitted ? "Checking..." : "Authorize"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeSmall
                                font.weight: Fonts.weightBold
                                color: Theme.darker_background
                            }
                        }

                        MouseArea {
                            id: authMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.submitted && root.responseRequired
                            onClicked: root.submitResponse()
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "polkit"
        function test(): string {
            root.currentMessage = "Authentication is required to modify system network settings"
            root.currentPrompt = "Password:"
            root.responseRequired = true
            root.testMode = true
            return "ok"
        }
        function close(): string {
            root.testMode = false
            return "ok"
        }
    }
}
