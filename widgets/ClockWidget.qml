import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import "../services"
import "../services/ClockModel.js" as Model

Item {
    id: root

    property PowerService powerService: null

    property date today: new Date()
    property date now: new Date()
    readonly property string todayKey: Model.keyForDate(today)

    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0-indexed

    readonly property date viewDate: new Date(viewYear, viewMonth, 1)
    readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

    readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

    // 0 = Sunday start (matching screenshot SUN, MON, TUE...)
    readonly property int weekStart: 0
    readonly property var weekdays: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var current = new Date()
            root.now = current
            if (current.getDate() !== root.today.getDate() || current.getMonth() !== root.today.getMonth() || current.getFullYear() !== root.today.getFullYear()) {
                root.today = current
            }
        }
    }

    function goToToday() {
        var current = new Date()
        root.now = current
        root.today = current
        root.viewYear = current.getFullYear()
        root.viewMonth = current.getMonth()
    }

    function toggle() {
        clockPopup.toggle()
        if (clockPopup.open) root.goToToday()
    }

    function moveMonth(delta) {
        var next = Model.stepMonth(viewYear, viewMonth, delta)
        root.viewYear = next.year
        root.viewMonth = next.month
    }

    function formatTime(d) {
        var h = String(d.getHours()).padStart(2, "0")
        var m = String(d.getMinutes()).padStart(2, "0")
        return h + ":" + m
    }

    function formatDayTime(d) {
        var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[d.getDay()] + " " + formatTime(d)
    }

    implicitWidth: clockButton.implicitWidth
    implicitHeight: clockButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: clockButton
        icon: ""
        text: root.formatDayTime(root.now)
        active: clockPopup.open
        onClicked: {
            clockPopup.toggle()
            if (clockPopup.open) root.goToToday()
        }
    }

    PopupCard {
        id: clockPopup
        anchorItem: clockButton
        showDefaultHeader: false
        contentWidth: 380
        contentHeight: 375

        WheelHandler {
            onWheel: function(event) {
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Column {
            id: calendarCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 12

            // ================= 1. HERO (Calendar Glyph + Date) =================
            Item {
                width: parent.width
                height: 48

                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    // Calendar Glyph
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰃭"
                        color: heroMouse.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Icons.effectiveFont("󰃭")
                        font.pixelSize: 38
                    }

                    // Date Label (e.g. "October 10")
                    Text {
                        id: heroDateText
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(root.today, "MMMM d")
                        color: heroMouse.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Fonts.uiFont
                        font.pixelSize: 34
                        font.bold: true
                    }
                }

                MouseArea {
                    id: heroMouse
                    anchors.fill: parent
                    hoverEnabled: !root.viewingCurrentMonth
                    cursorShape: root.viewingCurrentMonth ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.goToToday()
                }
            }

            // ================= 2. YEAR PROGRESS RAIL =================
            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    width: parent.width - 24

                    // Year label (e.g. "2026")
                    Text {
                        text: root.today.getFullYear()
                        color: Theme.muted
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Progress Track
                    Rectangle {
                        id: yearTrack
                        height: 5
                        radius: 2.5
                        color: Theme.selection
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 76

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: Math.round(parent.width * root.yearDone)
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    // Year percentage (e.g. "77%")
                    Text {
                        text: root.yearDonePercent + "%"
                        color: Theme.muted
                        font.family: Fonts.monoFont
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ================= 3. CALENDAR MONTH GRID =================
            Item {
                width: parent.width
                height: 220

                // Vertical hairline separating week numbers from days
                Rectangle {
                    x: 44
                    y: 20
                    width: 1
                    height: 195
                    color: Theme.selection
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    // Weekday Header Row
                    Row {
                        spacing: 2

                        // Week column header "W"
                        Item {
                            width: 38
                            height: 18

                            Text {
                                anchors.centerIn: parent
                                text: "W"
                                color: Theme.muted
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1
                            }
                        }

                        // Gutter space before day headers
                        Item { width: 8; height: 18 }

                        // Days headers: SUN, MON, TUE, WED, THU, FRI, SAT
                        Repeater {
                            model: root.weekdays

                            Item {
                                required property string modelData
                                width: 42
                                height: 18

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Theme.muted
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                }
                            }
                        }
                    }

                    // 6 Weeks Rows
                    Repeater {
                        model: root.weeks

                        Row {
                            id: weekRow
                            required property var modelData
                            spacing: 2

                            // Week number column (e.g. "40", "41", ...)
                            Item {
                                width: 38
                                height: 30

                                Text {
                                    anchors.centerIn: parent
                                    text: weekRow.modelData.week
                                    color: Theme.muted
                                    font.family: Fonts.monoFont
                                    font.pixelSize: 11
                                }
                            }

                            // Gutter space
                            Item { width: 8; height: 30 }

                            // 7 Days in Week
                            Repeater {
                                model: weekRow.modelData.days

                                Rectangle {
                                    id: dayCell
                                    required property var modelData

                                    width: 42
                                    height: 30
                                    radius: Appearance.radiusXs
                                    color: "transparent"
                                    border.width: modelData.today ? 1 : 0
                                    border.color: modelData.today ? Theme.selection : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.modelData.day
                                        color: {
                                            if (dayCell.modelData.today) return Theme.foreground
                                            if (dayCell.modelData.inMonth) return Theme.foreground
                                            return Theme.dark_foreground
                                        }
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        font.bold: dayCell.modelData.today 
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================= 4. FOOTER / MONTH NAVIGATION =================
            Item {
                width: parent.width
                height: 26

                Row {
                    anchors.centerIn: parent
                    spacing: 40

                    // Prev Month Chevron (<)
                    Text {
                        text: "󰅁"
                        font.family: Icons.effectiveFont("󰅁")
                        font.pixelSize: 14
                        color: prevM.containsMouse ? Theme.foreground : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            id: prevM
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveMonth(-1)
                        }
                    }

                    // Month & Year Label (e.g. "OCTOBER 2026")
                    Text {
                        text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                        color: Theme.muted
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Next Month Chevron (>)
                    Text {
                        text: "󰅂"
                        font.family: Icons.effectiveFont("󰅂")
                        font.pixelSize: 14
                        color: nextM.containsMouse ? Theme.foreground : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            id: nextM
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveMonth(1)
                        }
                    }
                }
            }
        }
    }
}
