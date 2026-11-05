import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Popup stack in the top-right corner of the focused screen, newest on top. The window only exists
// while there is something to show, and only the cards take clicks; the rest lets them through.
PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors { top: true; right: true }
    margins { top: Theme.inset; right: Theme.inset }
    implicitWidth: 360
    implicitHeight: Math.max(1, stack.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Notifications.popups.length > 0
    mask: Region { item: stack }

    WlrLayershell.namespace: "qs-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: stack
        spacing: 8
        move: Transition { NumberAnimation { properties: "y"; duration: Theme.animNormal; easing.type: Theme.easing } }
        Repeater {
            model: Notifications.popups
            delegate: NotificationCard {
                required property var modelData
                notification: modelData
                popup: true
            }
        }
    }
}
