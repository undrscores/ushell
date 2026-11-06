import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Alt+Tab style window switcher and window search (see services/Switcher.qml for the IPC calls).
// Tab / Shift+Tab or the arrows move, Enter or a click picks, typing filters, Esc cancels.
// Opened with `switcher next`, letting go of the modifier picks the highlighted window.
Overlay {
    id: root
    name: "switcher"
    scrim: 0.35
    onOpenChanged: if (open) { Switcher.query = ""; input.text = ""; Qt.callLater(() => input.forceActiveFocus()) }       // typing broke the text binding: clear it by hand

    readonly property int cols: Math.max(1, Math.min(5, Switcher.entries.length))
    readonly property int cellW: 150
    readonly property int cellH: 124

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cols * root.cellW + 2 * pad + (root.cols - 1) * 8
        readonly property int pad: 16
        height: field.height + 12 + Math.max(grid.height, Switcher.entries.length === 0 ? 36 : 0) + 2 * pad
        radius: Theme.radiusLarge
        color: Theme.glass
        border { width: 1; color: Theme.line }
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale { Spring { preset: root.open ? "popIn" : "popOut"; epsilon: 0.002 } }
        Behavior on width { Spring { preset: "settle"; epsilon: 0.4 } }
        Behavior on height { Spring { preset: "settle"; epsilon: 0.4 } }
        MouseArea { anchors.fill: parent }          // clicks on the card must not close it

        Rectangle {
            id: field
            x: card.pad; y: card.pad
            width: parent.width - 2 * card.pad
            height: 36
            radius: Theme.radius
            color: Theme.tint
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; text: ""; size: 14; color: Theme.fgDim }
            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 38; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                font { family: Theme.font; pixelSize: Theme.fontSize + 1 }
                clip: true
                onTextChanged: { if (text !== Switcher.query) Switcher.cycle = false; Switcher.query = text }
                Text {
                    visible: input.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: Switcher.entries.length + (Switcher.entries.length === 1 ? " window" : " windows") + "  ·  type to search"
                    color: Theme.fgDim
                    font: input.font
                }
                Keys.onPressed: event => {
                    const k = event.key
                    if (k === Qt.Key_Tab) { Switcher.step(1); event.accepted = true }
                    else if (k === Qt.Key_Backtab) { Switcher.step(-1); event.accepted = true }
                    else if (k === Qt.Key_Right) { Switcher.cycle = false; Switcher.step(1); event.accepted = true }
                    else if (k === Qt.Key_Left) { Switcher.cycle = false; Switcher.step(-1); event.accepted = true }
                    else if (k === Qt.Key_Down || k === Qt.Key_Up) {
                        const n = Switcher.entries.length, d = (k === Qt.Key_Down ? 1 : -1) * root.cols
                        const t = Switcher.index + d
                        if (t >= 0 && t < n) Switcher.index = t
                        Switcher.cycle = false
                        event.accepted = true
                    }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) { Switcher.pick(Switcher.index); event.accepted = true }
                    else if (k === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) { Switcher.closeWindow(Switcher.index); event.accepted = true }
                    else if (k === Qt.Key_Escape) { Shell.close(); event.accepted = true }
                }
                // Alt+Tab: the modifier coming up chooses the window
                Keys.onReleased: event => {
                    if (!Switcher.cycle) return
                    if ([Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control, Qt.Key_AltGr].includes(event.key)) {
                        Switcher.pick(Switcher.index); event.accepted = true
                    }
                }
            }
        }

        Grid {
            id: grid
            x: card.pad; y: card.pad + field.height + 12
            columns: root.cols
            spacing: 8
            Repeater {
                model: Switcher.entries
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: index === Switcher.index
                    width: root.cellW; height: root.cellH
                    radius: Theme.radius
                    color: current ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : Theme.tint)
                    border { width: 1; color: current ? Theme.accent : "transparent" }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Image {
                        id: appIcon
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
                        width: 44; height: 44
                        sourceSize: Qt.size(88, 88)
                        source: cell.modelData.icon ? Quickshell.iconPath(cell.modelData.icon, true) : ""
                        visible: status === Image.Ready
                        asynchronous: true
                    }
                    Icon { anchors.centerIn: appIcon; visible: !appIcon.visible; text: ""; size: 28; color: Theme.fgDim }
                    Rectangle {   // urgent window
                        visible: cell.modelData.urgent
                        x: appIcon.x + appIcon.width - 6; y: appIcon.y - 2
                        width: 10; height: 10; radius: 5; color: Theme.danger
                    }
                    Text {
                        anchors { left: parent.left; right: parent.right; top: appIcon.bottom; margins: 8; topMargin: 8 }
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.title
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1; bold: cell.current }
                    }
                    Text {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8; bottomMargin: 6 }
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.where
                        elide: Text.ElideRight
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onPositionChanged: { Switcher.index = cell.index; Switcher.cycle = false }       // real movement only, not a panel appearing under a resting pointer
                        onClicked: mouse => { if (mouse.button === Qt.MiddleButton) Switcher.closeWindow(cell.index); else Switcher.pick(cell.index) }
                    }
                    Rectangle {   // close button on hover
                        visible: ma.containsMouse
                        anchors { right: parent.right; top: parent.top; margins: 6 }
                        width: 20; height: 20; radius: 10
                        color: xMa.containsMouse ? Theme.danger : Theme.tint
                        Icon { anchors.centerIn: parent; text: ""; size: 10; color: xMa.containsMouse ? Theme.accentFg : Theme.fgDim }
                        MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: Switcher.closeWindow(cell.index) }
                    }
                }
            }
        }
        Text {
            visible: Switcher.entries.length === 0
            anchors { horizontalCenter: parent.horizontalCenter; top: field.bottom; topMargin: 18 }
            text: Switcher.query === "" ? "No windows open" : "No window matches"
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize }
        }
    }
}
