import QtQuick
import "../config"

// "HH:MM" box: saves when you press Enter or leave it, and only if it is a valid time.
Rectangle {
    id: root
    property string value
    signal edited(string v)
    implicitWidth: 64; implicitHeight: 30
    radius: Theme.radiusSmall + 2
    color: Theme.bg
    border { width: 1; color: input.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : Theme.line }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
        color: Theme.fg; clip: true; text: root.value
        inputMask: "99:99"
        selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
        font { family: Theme.font; pixelSize: Theme.fontSize }
        function commit() { if (/^([01]\d|2[0-3]):[0-5]\d$/.test(text)) root.edited(text); else text = root.value }
        onAccepted: { commit(); focus = false }
        onActiveFocusChanged: if (!activeFocus) commit()
        Keys.onEscapePressed: focus = false
    }
}
