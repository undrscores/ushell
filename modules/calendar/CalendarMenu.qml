import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Month calendar under the clock, with the day's agenda from the .ics files in Config.calendarPaths.
// Click the clock in the bar, or `qs ipc call shell toggle calendar`. Left / right (or PgUp / PgDn) change month.
Overlay {
    id: root
    name: "calendar"
    onOpenChanged: {
        Calendar.active = open
        if (open) { Calendar.goToday(); Calendar.forceRefresh(); Qt.callLater(() => keys.forceActiveFocus()) }
    }

    readonly property var weekdays: {
        const out = []
        for (let i = 0; i < 7; i++) out.push(Qt.locale().dayName((Calendar.firstDow + i) % 7, Locale.NarrowFormat))
        return out
    }
    readonly property var dayEvents: Calendar.eventsOn(Calendar.selected)
    readonly property string selectedTitle: Qt.formatDate(Calendar.parseIso(Calendar.selected), "dddd d MMMM")

    // keyboard: arrows / PgUp / PgDn change month, T jumps to today (Esc is handled by Overlay)
    Item {
        id: keys
        anchors.fill: parent
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) { Calendar.step(-1); event.accepted = true }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) { Calendar.step(1); event.accepted = true }
            else if (event.key === Qt.Key_T) { Calendar.goToday(); event.accepted = true }
        }
    }

    DropCard {
        id: card
        open: root.open
        contentWidth: 340
        contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 12

            // month header
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDate(Calendar.viewMonth, "MMMM yyyy")
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 3; bold: true }
                }
                Pill { label: "Today"; onClicked: Calendar.goToday() }
                IconButton { icon: ""; size: 28; onClicked: Calendar.step(-1) }
                IconButton { icon: ""; size: 28; onClicked: Calendar.step(1) }
            }

            // weekday names
            Row {
                Layout.fillWidth: true
                Repeater {
                    model: root.weekdays
                    delegate: Text {
                        required property string modelData
                        width: card.contentWidth / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                    }
                }
            }

            // the grid
            Grid {
                id: grid
                Layout.fillWidth: true
                columns: 7
                readonly property real cell: card.contentWidth / 7
                Repeater {
                    model: Calendar.days
                    delegate: Item {
                        id: cellItem
                        required property var modelData
                        readonly property bool isToday: modelData.iso === Calendar.today
                        readonly property bool isSelected: modelData.iso === Calendar.selected
                        readonly property var evs: Calendar.eventsOn(modelData.iso)
                        width: grid.cell; height: 42

                        Rectangle {
                            anchors.centerIn: parent
                            width: 36; height: 36; radius: 18
                            color: cellItem.isToday ? Theme.accent : (cellItem.isSelected ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : "transparent"))
                            border { width: cellItem.isSelected && cellItem.isToday ? 2 : 0; color: Theme.accentFg }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: cellItem.evs.length > 0 ? -2 : 0 }
                            text: cellItem.modelData.day
                            color: cellItem.isToday ? Theme.accentFg : (cellItem.modelData.inMonth ? Theme.fg : Theme.fgDim)
                            opacity: cellItem.modelData.inMonth || cellItem.isToday ? 1 : 0.5
                            font { family: Theme.font; pixelSize: Theme.fontSize; bold: cellItem.isToday }
                        }
                        Row {   // one dot per event, up to three
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                            spacing: 3
                            Repeater {
                                model: Math.min(3, cellItem.evs.length)
                                delegate: Rectangle { width: 4; height: 4; radius: 2; color: cellItem.isToday ? Theme.accentFg : Theme.accent }
                            }
                        }
                        MouseArea {
                            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Calendar.selected = cellItem.modelData.iso
                                if (!cellItem.modelData.inMonth) Calendar.show(cellItem.modelData.date.getFullYear(), cellItem.modelData.date.getMonth())
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }

            // agenda of the selected day
            Text {
                text: root.selectedTitle
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize + 1; bold: true }
            }
            Repeater {
                model: root.dayEvents
                delegate: RowLayout {
                    id: ev
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle { Layout.alignment: Qt.AlignTop; Layout.topMargin: 2; width: 3; Layout.preferredHeight: evText.implicitHeight; radius: 1.5; color: Theme.accent }
                    ColumnLayout {
                        id: evText
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: ev.modelData.title
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: Theme.fontSize }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Calendar.clockText(ev.modelData, Calendar.selected) + (ev.modelData.location ? "  ·  " + ev.modelData.location : "")
                            elide: Text.ElideRight
                            color: Theme.fgDim
                            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                        }
                    }
                }
            }
            Text {
                visible: root.dayEvents.length === 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Calendar.loading ? "Reading calendars…"
                    : (Calendar.failed ? "Could not read the calendar files."
                    : (Calendar.events.length === 0 ? "No events found. Put .ics files in " + Config.calendarPaths[0] + " (or set calendarPaths in config.json); vdirsyncer folders work too."
                    : "Nothing planned."))
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
        }
    }
}
