import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// A banner under the top edge while uwm's config fails to load (snapshot `config_error`); gone once
// the config loads again. Click-through.
PanelWindow {
    id: win
    readonly property string err: Uwm.state.config_error ?? ""
    screen: Quickshell.screens.find(s => s.name === Wm.focusedOutput) ?? Quickshell.screens[0]
    anchors { top: true }
    margins { top: Theme.edgeGap + Theme.barHeight + 12 }
    implicitWidth: Math.min(640, (screen ? screen.width : 800) - 40)
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: err !== "" || card.opacity > 0.01
    mask: Region {}
    WlrLayershell.namespace: "ushell-config-error"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property string shown: ""
    onErrChanged: if (err !== "") shown = err

    Glass {
        id: card
        width: parent.width
        height: text.implicitHeight + 28
        opacity: win.err !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 } width: 3; radius: 1.5; color: Theme.danger }
        Text {
            id: text
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 22; rightMargin: 16 }
            text: "uwm config error: " + win.shown
            wrapMode: Text.Wrap
            color: Theme.fg
            font { family: Theme.font; pixelSize: Theme.fontSize }
        }
    }
}
