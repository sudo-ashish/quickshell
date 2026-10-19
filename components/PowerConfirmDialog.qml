import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property PowerService powerService

    readonly property bool isOpen: root.powerService && root.powerService.confirmOpen

    visible: root.isOpen
    screen: (root.powerService && root.powerService.targetScreen) ? root.powerService.targetScreen : null
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "quickshell-confirm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: {
            if (root.powerService) {
                root.powerService.cancelConfirm()
            }
        }
    }

    // Keyboard navigation (Esc to cancel, Enter/Return to execute)
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.isOpen

        Keys.onEscapePressed: {
            if (root.powerService) root.powerService.cancelConfirm()
        }
        Keys.onReturnPressed: {
            if (root.powerService) root.powerService.executeConfirmed()
        }
        Keys.onEnterPressed: {
            if (root.powerService) root.powerService.executeConfirmed()
        }
    }

    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus()
        }
    }

    // Semi-transparent backdrop overlay
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Appearance.animDurationNormal; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.powerService) root.powerService.cancelConfirm()
            }
        }
    }

    // Centered Confirmation Dialog Box
    Rectangle {
        id: dialogCard
        width: 380
        height: 190
        anchors.centerIn: parent
        radius: Appearance.dialogRadius
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.color: Theme.selection
        border.width: Appearance.borderWidthThin

        opacity: root.isOpen ? 1.0 : 0.0
        scale: root.isOpen ? 1.0 : 0.95

        Behavior on opacity {
            NumberAnimation { duration: Appearance.animDurationNormal; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Appearance.animDurationNormal; easing.type: Easing.OutCubic }
        }

        // Prevent clicks on the card from falling through to the backdrop
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) { mouse.accepted = false }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.paddingXl + 2 // 22px
            spacing: Appearance.spacingXl

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacingXl

                // Action Icon Badge
                Rectangle {
                    width: Appearance.osdHeight
                    height: Appearance.osdHeight
                    radius: Appearance.radiusPill
                    readonly property bool isUrgent: root.powerService && root.powerService.confirmAction === "poweroff"
                    color: Theme.darker_background
                    border.color: isUrgent ? Theme.red : Theme.yellow
                    border.width: Appearance.borderWidthThin

                    Text {
                        anchors.centerIn: parent
                        text: root.powerService ? root.powerService.confirmIcon : ""
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.sizeTitle
                        color: parent.isUrgent ? Theme.red : Theme.yellow
                    }
                }

                // Title and prompt text
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacingSmall

                    Text {
                        Layout.fillWidth: true
                        text: root.powerService ? root.powerService.confirmTitle : ""
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeLarge
                        font.bold: true
                        color: Theme.foreground
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.powerService ? root.powerService.confirmMessage : ""
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeSmall
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacingLarge

                // Cancel Button
                Rectangle {
                    id: cancelBtn
                    Layout.fillWidth: true
                    height: Appearance.popupHeaderHeight
                    radius: Appearance.buttonRadius
                    color: cancelMouse.containsMouse ? Theme.lighter_background : Theme.dark_background
                    border.color: cancelMouse.containsMouse ? Theme.accent : Theme.selection
                    border.width: Appearance.borderWidthThin

                    Row {
                        anchors.centerIn: parent
                        spacing: Appearance.spacingMedium - 2 // 6px

                        Text {
                            text: Icons.close
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.sizeRegular
                            color: cancelMouse.containsMouse ? Theme.foreground : Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Cancel"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: cancelMouse.containsMouse ? Theme.foreground : Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.powerService) root.powerService.cancelConfirm()
                        }
                    }
                }

                // Confirm Action Button
                Rectangle {
                    id: confirmBtn
                    Layout.fillWidth: true
                    height: Appearance.popupHeaderHeight
                    radius: Appearance.buttonRadius
                    readonly property bool isUrgent: root.powerService && root.powerService.confirmAction === "poweroff"
                    readonly property color themeColor: isUrgent ? Theme.red : Theme.yellow

                    color: {
                        if (confirmMouse.containsMouse) return themeColor
                        return Theme.selection
                    }
                    border.color: themeColor
                    border.width: Appearance.borderWidthThin

                    Row {
                        anchors.centerIn: parent
                        spacing: Appearance.spacingMedium - 2 // 6px

                        Text {
                            text: root.powerService ? root.powerService.confirmIcon : ""
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.sizeRegular
                            color: confirmMouse.containsMouse ? Theme.darker_background : confirmBtn.themeColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.powerService && root.powerService.confirmAction === "poweroff" ? "Power Off" : "Restart"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: confirmMouse.containsMouse ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.powerService) root.powerService.executeConfirmed()
                        }
                    }
                }
            }
        }
    }
}
