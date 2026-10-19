import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"
import "NotificationLogic.js" as NotificationLogic

Item {
    id: root

    property bool doNotDisturb: false
    property var liveRefs: ({})
    property alias popupModel: popupModel
    ListModel { id: popupModel }

    readonly property int lowPopupDuration: 5000
    readonly property int normalPopupDuration: 8000
    readonly property int maxPopupDuration: 30000

    function durationFor(urgency, expireTimeout) {
        if (urgency === 2) { // Critical
            return 0
        }
        var timeoutMs = Number(expireTimeout || 0)
        if (timeoutMs > 0) {
            return Math.min(maxPopupDuration, Math.max(lowPopupDuration, timeoutMs))
        }
        return urgency === 0 ? lowPopupDuration : normalPopupDuration
    }

    function handleNotification(notification) {
        if (!notification) return

        // Keep Notification object alive in C++ engine
        notification.tracked = true

        var snapshot = NotificationLogic.snapshotOf(notification)
        liveRefs[snapshot.originalId] = notification

        notification.closed.connect(function() {
            if (root.liveRefs[snapshot.originalId] === notification) {
                delete root.liveRefs[snapshot.originalId]
            }
        })

        // Check DND silencing
        if (root.doNotDisturb && !NotificationLogic.shouldBypassDnd(notification, 2)) {
            delete root.liveRefs[snapshot.originalId]
            notification.tracked = false
            return
        }

        // Watch for in-place property updates (replaces_id)
        watchForUpdates(notification, snapshot)

        // Remove any existing toast with the same originalId
        removePopupsByOriginalId(snapshot.originalId)

        // Add new notification to top of list
        snapshot.remainingLifetime = 1.0
        popupModel.insert(0, snapshot)
    }

    function removePopupsByOriginalId(originalId) {
        for (var i = popupModel.count - 1; i >= 0; i--) {
            var row = popupModel.get(i)
            if (row && row.originalId === originalId) {
                popupModel.remove(i)
            }
        }
    }

    readonly property var updateSignals: [
        "summaryChanged", "bodyChanged", "appNameChanged", "appIconChanged",
        "imageChanged", "urgencyChanged", "expireTimeoutChanged", "hintsChanged"
    ]

    function watchForUpdates(notification, snapshot) {
        function refresh() {
            root.refreshPopup(notification, snapshot.originalId, snapshot.timestamp)
        }

        for (var i = 0; i < updateSignals.length; i++) {
            var sig = notification[updateSignals[i]]
            if (sig && typeof sig.connect === "function") {
                sig.connect(refresh)
            }
        }
    }

    function refreshPopup(notification, originalId, timestamp) {
        if (root.liveRefs[originalId] !== notification) return

        var updated = null
        try {
            updated = NotificationLogic.replacementSnapshot(notification, originalId, timestamp)
        } catch (e) {
            return
        }

        var roles = NotificationLogic.popupRoles()
        for (var i = 0; i < popupModel.count; i++) {
            var row = popupModel.get(i)
            if (!row || row.originalId !== originalId) continue
            if (!NotificationLogic.popupRowChanged(row, updated)) return
            for (var r = 0; r < roles.length; r++) {
                popupModel.setProperty(i, roles[r], updated[roles[r]])
            }
            return
        }
    }

    function dismissPopup(index) {
        removePopup(index, "dismiss")
    }

    function expirePopup(index) {
        removePopup(index, "expire")
    }

    function removePopup(index, reason) {
        if (index < 0 || index >= popupModel.count) return
        var entry = popupModel.get(index)
        var originalId = entry ? entry.originalId : -1
        var ref = originalId >= 0 ? liveRefs[originalId] : null

        popupModel.remove(index)
        if (originalId >= 0) {
            root.setNotificationHovered(originalId, false)
        }

        if (ref) {
            try {
                if (ref.tracked) {
                    if (reason === "expire" && typeof ref.expire === "function") {
                        ref.expire()
                    } else if (typeof ref.dismiss === "function") {
                        ref.dismiss()
                    }
                }
            } catch (e) {
            }
        }
    }

    function clearPopups() {
        while (popupModel.count > 0) {
            dismissPopup(0)
        }
    }

    function invokePopupDefault(index) {
        if (index < 0 || index >= popupModel.count) return
        var entry = popupModel.get(index)
        if (!entry) return

        // 1. Try qdeck-exec-argv hint if provided
        var argv = NotificationLogic.parseExecArgv(entry.execArgv)
        if (argv && argv.length > 0) {
            runProcess(argv)
            dismissPopup(index)
            return
        }

        // 2. Try notification's "default" action
        var ref = liveRefs[entry.originalId]
        var invoked = false
        try {
            if (ref && ref.actions) {
                for (var i = 0; i < ref.actions.length; i++) {
                    var action = ref.actions[i]
                    if (action && action.identifier === "default") {
                        action.invoke()
                        invoked = true
                        break
                    }
                }
            }
        } catch (e) {
        }

        // 3. Fallback: focus window matching sender application
        if (!invoked && entry.app) {
            focusApp(entry.app)
        }

        dismissPopup(index)
    }

    function invokePopupAction(index, actionId) {
        if (index < 0 || index >= popupModel.count) return
        var entry = popupModel.get(index)
        if (!entry) return

        var ref = liveRefs[entry.originalId]
        try {
            if (ref && ref.actions) {
                for (var i = 0; i < ref.actions.length; i++) {
                    var action = ref.actions[i]
                    if (action && action.identifier === actionId) {
                        action.invoke()
                        break
                    }
                }
            }
        } catch (e) {
        }

        dismissPopup(index)
    }

    Process { id: appProc; running: false }

    function runProcess(args) {
        if (!args || args.length === 0) return
        appProc.command = args
        appProc.running = true
    }

    function focusApp(appName) {
        if (!appName) return
        // Focus window using hyprctl dispatch
        runProcess(["hyprctl", "dispatch", "focuswindow", "class:(?i)" + appName])
    }

    // Settings persistence (DND state)
    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/notifications.json"
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var d = JSON.parse(text() || "{}")
                if (typeof d.dnd === "boolean") {
                    root.doNotDisturb = d.dnd
                }
            } catch (e) {}
        }
    }

    function saveSettings() {
        var payload = JSON.stringify({ dnd: root.doNotDisturb }, null, 2) + "\n"
        settingsFile.setText(payload)
    }

    // ---------------------------------------------------- IPC
    IpcHandler {
        target: "notifications"

        function dndState(): string {
            return root.doNotDisturb ? "on" : "off"
        }

        function toggleDnd(): string {
            root.doNotDisturb = !root.doNotDisturb
            root.saveSettings()
            return root.doNotDisturb ? "on" : "off"
        }

        function setDnd(value: string): string {
            var v = String(value || "").toLowerCase()
            root.doNotDisturb = (v === "true" || v === "1" || v === "on" || v === "yes")
            root.saveSettings()
            return root.doNotDisturb ? "on" : "off"
        }

        function isDnd(): string {
            return dndState()
        }

        function dismissAll(): string {
            root.clearPopups()
            return "ok"
        }

        function dismissOne(): string {
            if (popupModel.count === 0) return "none"
            root.dismissPopup(0)
            return "ok"
        }

        function dismiss(summary: string): string {
            var needle = String(summary || "")
            if (!needle) return "none"
            var hit = false
            for (var i = popupModel.count - 1; i >= 0; i--) {
                var row = popupModel.get(i)
                if (row && String(row.summary || "").indexOf(needle) !== -1) {
                    root.dismissPopup(i)
                    hit = true
                }
            }
            return hit ? "ok" : "none"
        }

        function invokeLast(): string {
            if (popupModel.count === 0) return "none"
            root.invokePopupDefault(0)
            return "ok"
        }

        function count(): string {
            return String(popupModel.count)
        }

        function show(payloadJson: string): string {
            try {
                var p = JSON.parse(payloadJson || "{}")
                var urg = 1
                if (p.urgency === "critical" || p.urgency === 2 || p.urgency === "2") urg = 2
                else if (p.urgency === "low" || p.urgency === 0 || p.urgency === "0") urg = 0
                var snap = {
                    id: Date.now() % 100000,
                    originalId: Date.now() % 100000,
                    app: p.app || "System",
                    appIcon: p.icon || "",
                    summary: p.summary || "Notification",
                    body: p.body || "",
                    image: p.image || "",
                    glyph: p.glyph || "󰂚",
                    execArgv: p.execArgv || "",
                    urgency: urg,
                    expireTimeout: urg === 2 ? 0 : (p.timeout ? Number(p.timeout) : 6000),
                    timestamp: Date.now(),
                    actionsJson: p.actions ? JSON.stringify(p.actions) : "[]",
                    remainingLifetime: 1.0
                }
                popupModel.insert(0, snap)
                return "ok"
            } catch (e) {
                return "error: " + e
            }
        }

        function test(summary: string, body: string): string {
            return show(JSON.stringify({
                summary: summary || "QuickShell Notification",
                body: body || "Your custom notification service is running successfully!",
                app: "QuickShell",
                glyph: "󰂚",
                urgency: 1,
                timeout: 6000
            }))
        }

        function ping(): string {
            return "ok"
        }
    }

    // ---------------------------------------------------- Server
    NotificationServer {
        id: server
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true

        onNotification: function(notification) {
            root.handleNotification(notification)
        }
    }

    // ---------------------------------------------------- Single Expiry Controller
    property var hoveredMap: ({})

    function setNotificationHovered(origId, isHovered) {
        if (origId === undefined || origId === null) return
        var next = Object.assign({}, root.hoveredMap)
        if (isHovered) {
            next[origId] = true
        } else {
            delete next[origId]
        }
        root.hoveredMap = next
    }

    Timer {
        id: expiryController
        interval: 50
        repeat: true
        running: popupModel.count > 0
        onTriggered: {
            for (var i = popupModel.count - 1; i >= 0; i--) {
                var row = popupModel.get(i)
                if (!row) continue

                var origId = row.originalId
                if (root.hoveredMap[origId]) continue

                var lifetime = root.durationFor(row.urgency, row.expireTimeout)
                if (lifetime <= 0) continue

                var cur = row.remainingLifetime !== undefined ? row.remainingLifetime : 1.0
                var nextLife = cur - (50.0 / lifetime)
                if (nextLife <= 0) {
                    delete root.hoveredMap[origId]
                    root.expirePopup(i)
                } else {
                    popupModel.setProperty(i, "remainingLifetime", nextLife)
                }
            }
        }
    }

    // ---------------------------------------------------- Popup UI
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: popupWindow
            required property var modelData
            screen: modelData
            visible: popupModel.count > 0

            WlrLayershell.namespace: "quickshell-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }

            // Click-through except over toasts
            mask: Region { item: popupColumn }

            ColumnLayout {
                id: popupColumn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Appearance.notificationTopMargin
                anchors.rightMargin: Appearance.notificationRightMargin
                spacing: Appearance.notificationSpacing

                Repeater {
                    model: popupModel

                    delegate: Item {
                        id: cardSlot
                        required property int index
                        required property int originalId
                        required property string app
                        required property string appIcon
                        required property string summary
                        required property string body
                        required property string image
                        required property string glyph
                        required property int urgency
                        required property double expireTimeout
                        required property double timestamp
                        required property string actionsJson
                        required property real remainingLifetime

                        Layout.preferredWidth: card.implicitWidth
                        Layout.alignment: Qt.AlignRight
                        implicitHeight: card.implicitHeight

                        readonly property real lifetime: root.durationFor(cardSlot.urgency, cardSlot.expireTimeout)

                        NotificationCard {
                            id: card
                            anchors.right: parent.right
                            app: cardSlot.app
                            appIcon: cardSlot.appIcon
                            summary: cardSlot.summary
                            body: cardSlot.body
                            image: cardSlot.image
                            glyph: cardSlot.glyph
                            urgency: cardSlot.urgency
                            timestamp: cardSlot.timestamp
                            actionsJson: cardSlot.actionsJson
                            progress: cardSlot.remainingLifetime !== undefined ? cardSlot.remainingLifetime : 1.0
                            hasTimeout: cardSlot.lifetime > 0

                            Connections {
                                target: card
                                function onHoveredChanged() {
                                    root.setNotificationHovered(cardSlot.originalId, card.hovered)
                                }
                            }

                            onCloseRequested: root.dismissPopup(cardSlot.index)
                            onCardClicked: root.invokePopupDefault(cardSlot.index)
                            onActionRequested: function(actionId) {
                                root.invokePopupAction(cardSlot.index, actionId)
                            }
                        }
                    }
                }
            }
        }
    }
}
