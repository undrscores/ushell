import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Focus tab: a countdown timer and a scratch note.
Item {
    id: page
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // ── timer ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 172
            radius: Theme.radius
            color: Theme.tint

            Text {
                x: 16; y: 12
                text: "Timer"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 28
                text: Countdown.fmt(Countdown.remaining)
                color: Countdown.running ? Theme.accent : Theme.fg
                font { family: Theme.font; pixelSize: 40; weight: Font.Light }
            }
            Rectangle {          // time left
                x: 16; y: 84; width: parent.width - 32; height: 4; radius: 2
                color: Theme.line
                Rectangle {
                    width: parent.width * Countdown.fraction; height: parent.height; radius: 2
                    color: Theme.accent
                }
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 104 }
                spacing: 6
                Repeater {
                    model: [5, 15, 25, 45]
                    delegate: Pill {
                        required property int modelData
                        label: modelData + "m"
                        active: Countdown.total === modelData * 60
                        opacity: Countdown.running ? 0.45 : 1
                        onClicked: Countdown.setMinutes(modelData)
                    }
                }
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 138 }
                spacing: 6
                Pill { label: Countdown.running ? "Pause" : (Countdown.active ? "Resume" : "Start"); active: true; onClicked: Countdown.toggle() }
                Pill { label: "Reset"; visible: Countdown.active; onClicked: Countdown.reset() }
            }
        }

        // ── scratch note ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 178
            radius: Theme.radius
            color: Theme.tint
            border { width: 1; color: edit.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }

            Text {
                x: 16; y: 12
                text: "Note"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
            Flickable {
                id: flick
                anchors { fill: parent; topMargin: 34; leftMargin: 16; rightMargin: 12; bottomMargin: 12 }
                contentWidth: width
                contentHeight: edit.height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                function follow() {
                    const r = edit.cursorRectangle
                    if (r.y < contentY) contentY = r.y
                    else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height
                }
                TextEdit {
                    id: edit
                    width: flick.width
                    height: Math.max(implicitHeight, flick.height)
                    wrapMode: TextEdit.Wrap
                    color: Theme.fg
                    selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    // the file may still be loading when the tab opens
                    text: Notes.text
                    onTextChanged: Notes.edit(text)
                    onCursorRectangleChanged: flick.follow()
                    Keys.onEscapePressed: focus = false
                    Text {
                        visible: !edit.text && !edit.activeFocus
                        text: "Jot something down…"
                        color: Theme.fgDim
                        font: edit.font
                    }
                }
            }
        }
    }
}
