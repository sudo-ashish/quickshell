import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

PanelWindow {
    id: root

    required property Item anchorItem
    property string title: ""
    property string icon: ""
    property bool open: false
    property int contentWidth: 320
    property int contentHeight: 280
    property bool showDefaultHeader: true
    property double lastClearedTime: 0

    function toggle() {
        if (Date.now() - root.lastClearedTime < 250) {
            root.open = false
            return
        }
        root.open = !root.open
    }

    default property alias content: bodyContainer.data

    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    screen: (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window.screen : null

    WlrLayershell.namespace: "quickshell-surface"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    // Dismiss when clicking outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    // Calculate card position relative to anchorItem
    readonly property real cardX: {
        var _ = root.open // reactively recompute whenever popup opens
        if (!root.anchorItem) return Appearance.popupMargin
        var pt = root.anchorItem.mapToItem(null, 0, 0)
        var desiredX = pt.x + (root.anchorItem.width / 2) - (root.contentWidth / 2)
        var margin = Appearance.popupMargin
        var maxRight = root.width - root.contentWidth - margin
        return Math.max(margin, Math.min(desiredX, maxRight))
    }

    readonly property real cardY: {
        var _ = root.open // reactively recompute whenever popup opens
        if (!root.anchorItem) return Appearance.barHeight + 6
        var pt = root.anchorItem.mapToItem(null, 0, 0)
        return Math.max(Appearance.barHeight + 6, pt.y + root.anchorItem.height + 6)
    }

    // Outer Card Container
    Rectangle {
        id: cardRect
        x: Math.round(root.cardX)
        y: Math.round(root.cardY)
        width: root.contentWidth
        height: root.contentHeight
        color: Theme.withAlpha(Theme.dark_background, Theme.baseOpacity)
        border.color: "transparent"
        border.width: Appearance.borderWidthNone
        radius: Appearance.popupRadius

        // Prevent clicks inside the card from closing the popup
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) { mouse.accepted = false }
        }

        // Card Header (Optional, default true)
        Item {
            id: headerRect
            visible: root.showDefaultHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.showDefaultHeader ? Appearance.popupHeaderHeight : 0

            // Bottom border of header
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Appearance.borderWidthThin
                color: Theme.selection
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacingMedium

                Text {
                    visible: root.icon.length > 0
                    text: root.icon
                    font.family: Icons.effectiveFont(root.icon)
                    font.pixelSize: Fonts.sizeMedium
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.title
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeMedium
                    font.weight: Fonts.weightBold
                    color: Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Body Content Container
        Item {
            id: bodyContainer
            anchors.top: root.showDefaultHeader ? headerRect.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.showDefaultHeader ? Appearance.paddingMedium : Appearance.popupPadding
        }
    }
}
