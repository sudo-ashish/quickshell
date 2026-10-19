import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "NotificationLogic.js" as NotificationLogic

Rectangle {
    id: root

    property string app: ""
    property string appIcon: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property string glyph: ""
    property int urgency: 1 // 0=Low, 1=Normal, 2=Critical
    property double timestamp: 0
    property string actionsJson: "[]"
    property real progress: 1.0 // 1.0 -> 0.0 remaining lifetime
    property bool hasTimeout: true

    readonly property bool hovered: hoverTracker.hovered

    signal closeRequested()
    signal cardClicked()
    signal actionRequested(string actionId)

    function iconSource(icon) {
        var value = String(icon || "").trim()
        if (value.length === 0) return ""
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
        if (value.charAt(0) === "/") return "file://" + value
        return Quickshell.iconPath(value, true)
    }

    readonly property string smallIconSource: image.length > 0 ? (image.charAt(0) === "/" ? "file://" + image : image) : iconSource(appIcon)
    readonly property bool hasIconSource: smallIconSource.length > 0
    readonly property string sanitizedBody: NotificationLogic.sanitizeBody(body, app, appIcon)
    readonly property string styledBody: NotificationLogic.styledBody(body, app, appIcon)

    readonly property color accentColor: urgency === 2 ? Theme.red : (urgency === 0 ? Theme.muted : Theme.accent)

    property var actionList: []
    Component.onCompleted: updateActionList()
    onActionsJsonChanged: updateActionList()

    function updateActionList() {
        try {
            actionList = JSON.parse(actionsJson || "[]")
        } catch (e) {
            actionList = []
        }
    }

    implicitWidth: Appearance.notificationWidth
    implicitHeight: mainColumn.implicitHeight + 20
    radius: Appearance.notificationRadius
    color: Theme.withAlpha(Theme.dark_background, Theme.baseOpacity)
    border.color: Theme.selection
    border.width: Appearance.borderWidthThin
    clip: true

    HoverHandler { id: hoverTracker }

    // Left accent strip indicating urgency
    Rectangle {
        id: urgencyStrip
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Appearance.notificationUrgencyStripWidth
        color: root.accentColor
        radius: Appearance.radiusXs
    }

    // Main clickable surface
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.closeRequested()
            } else {
                root.cardClicked()
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.spacingLarge
        anchors.leftMargin: Appearance.spacingXl
        anchors.rightMargin: Appearance.spacingLarge + 2
        spacing: Appearance.spacingMedium

        // Top Row: App Icon/Glyph, App Name, Close Button
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacingMedium

            // Icon / Glyph Slot
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: iconImg
                    anchors.fill: parent
                    source: root.smallIconSource
                    sourceSize.width: 44
                    sourceSize.height: 44
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: root.hasIconSource && iconImg.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !iconImg.visible
                    text: root.glyph.length > 0 ? root.glyph : Icons.bell
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Fonts.sizeMedium + 1
                    color: root.accentColor
                }
            }

            // App Name
            Text {
                Layout.fillWidth: true
                text: (root.app.length > 0 ? root.app : "System").toUpperCase()
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.sizeXs + 1
                font.weight: Fonts.weightBold
                color: Theme.muted
                elide: Text.ElideRight
            }

            // Close Button
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: closeBtnArea.containsMouse ? Theme.lighter_background : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: Icons.close
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Fonts.sizeSmall + 1
                    color: closeBtnArea.containsMouse ? Theme.red : Theme.muted
                }

                MouseArea {
                    id: closeBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Summary Title
        Text {
            Layout.fillWidth: true
            visible: root.summary.length > 0
            text: root.summary
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.sizeRegular + 1
            font.weight: Fonts.weightBold
            color: Theme.foreground
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        // Body Text
        Text {
            Layout.fillWidth: true
            visible: root.sanitizedBody.length > 0
            text: root.styledBody
            textFormat: Text.StyledText
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.sizeRegular
            color: Theme.foreground
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 4
        }

        // Actions Row (if any actions are defined)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacingSmall
            visible: root.actionList.length > 0
            spacing: Appearance.spacingMedium

            Repeater {
                model: root.actionList

                delegate: Rectangle {
                    required property var modelData
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: actionLabel.implicitWidth + 20
                    radius: Appearance.radiusSmall + 2
                    color: actionMouseArea.containsMouse ? Theme.lighter_background : Theme.selection
                    border.color: Theme.selection
                    border.width: Appearance.borderWidthThin

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: modelData.text || modelData.id
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeSmall
                        font.weight: Fonts.weightBold
                        color: Theme.foreground
                    }

                    MouseArea {
                        id: actionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.actionRequested(modelData.id)
                    }
                }
            }
        }
    }

    // Bottom subtle lifetime progress bar
    Rectangle {
        id: progressBar
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: Appearance.borderWidthMedium
        visible: root.hasTimeout
        color: root.accentColor
        width: parent.width * Math.max(0.0, Math.min(1.0, root.progress))

        Behavior on width {
            NumberAnimation { duration: 50 }
        }
    }
}
