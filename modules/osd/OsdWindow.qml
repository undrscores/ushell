import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// The volume / brightness pill (see services/Osd.qml). Sits above the bottom edge of the focused screen,
// lets every click through, and only exists while it is visible.
PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors { bottom: true }
    margins { bottom: 72 }
    implicitWidth: 280
    implicitHeight: 52
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Osd.shown || card.opacity > 0.01
    mask: Region {}                      // empty: nothing in this window takes the pointer

    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Glass {
        id: card
        width: parent.width
        height: parent.height
        opacity: Osd.shown ? 1 : 0
        transform: Translate { y: Osd.shown ? 0 : 10; Behavior on y { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } } }
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

        Row {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 12
            Icon {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                size: 20
                text: Osd.glyph
                color: Osd.muted ? Theme.danger : Theme.fg
            }
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - glyph.width - pct.width - 2 * parent.spacing
                height: 6
                radius: 3
                color: Theme.hover
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(height, track.width * Math.max(0, Math.min(1, Osd.value / Osd.limit)))
                    color: Osd.muted ? Theme.fgDim : (Osd.value > 1.0001 ? Theme.danger : Theme.accent)
                    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
                }
            }
            Text {
                id: pct
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: Osd.kind === "mic" ? (Osd.muted ? "off" : "on") : (Osd.muted ? "mute" : Math.round(Osd.value * 100))
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }
    }
}
