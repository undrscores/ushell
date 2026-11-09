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

    screen: Quickshell.screens.find(s => s.name === Wm.focusedOutput) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || linger.running

    // frosted glass: the compositor blurs what is behind the first panel in this overlay (ext-background-effect-v1)
    readonly property Item frostItem: {
        const kids = holder.children
        for (let i = 0; i < kids.length; i++) if (kids[i].isGlass === true) return kids[i]
        return null
    }
    BackgroundEffect.blurRegion: Region { item: Prefs.frostedPanels ? win.frostItem : null; radius: Theme.radiusLarge }

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
