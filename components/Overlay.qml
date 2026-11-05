import Quickshell
import Quickshell.Wayland
import QtQuick
import "../config"
import "../services"

// Full-screen transparent layer for a panel. Opens when Shell.overlay === name,
// lingers while the exit animation plays, closes on Esc / click outside.
PanelWindow {
    id: win
    required property string name
    readonly property bool open: Shell.overlay === name
    default property alias content: holder.data
    property real scrim: 0              // 0..1: how much the screen dims behind a modal panel (dropdowns leave it 0)

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || linger.running

    WlrLayershell.namespace: "qs-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (!open) linger.restart(); else holder.forceActiveFocus()
    Timer { id: linger; interval: Theme.animSlow }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrimColor
        opacity: win.open ? win.scrim : 0
        visible: opacity > 0.005
        Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }
    }
    MouseArea { anchors.fill: parent; onClicked: Shell.close() }
    Item {
        id: holder
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Shell.close()
    }
}
