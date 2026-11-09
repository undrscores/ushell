import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"

// Hot corners. Each screen corner has a small input zone; the pointer resting in it makes a glow swell
// from the corner and, after Prefs.hotCornerDwell ms, runs the corner's action (Prefs.hotCornerTL, TR, BL,
// BR): "uwm:COMMAND" sends that line to uwm (e.g. "uwm:overview"), "shell:NAME" toggles a panel
// (e.g. "shell:launcher"), empty = no action and no zone. The pointer has to leave and come back to fire again.
Variants {
    model: Prefs.hotCorners ? Quickshell.screens : []

    Scope {
        id: scope
        required property var modelData

        Repeater {
            model: [
                { id: "TL", top: true,  left: true },
                { id: "TR", top: true,  left: false },
                { id: "BL", top: false, left: true },
                { id: "BR", top: false, left: false }
            ]

            PanelWindow {
                id: win
                required property var modelData
                readonly property string action: Prefs["hotCorner" + modelData.id] ?? ""
                readonly property int zone: 4
                readonly property int size: 180

                screen: scope.modelData
                visible: action !== ""
                anchors { top: modelData.top; bottom: !modelData.top; left: modelData.left; right: !modelData.left }
                implicitWidth: size; implicitHeight: size
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                // only the corner pixels take the pointer
                mask: Region {
                    x: win.modelData.left ? 0 : win.size - win.zone
                    y: win.modelData.top ? 0 : win.size - win.zone
                    width: win.zone; height: win.zone
                }
                WlrLayershell.namespace: "ushell-hotcorner"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                property bool armed: true
                function run() {
                    armed = false
                    if (action.startsWith("shell:")) Shell.toggle(action.slice(6))
                    else if (action.startsWith("uwm:")) Uwm.send(action.slice(4))
                    ripple.restart()
                }

                HoverHandler {
                    id: hover
                    // the hover area is the whole window in item coordinates, so the mask decides what counts
                    onHoveredChanged: if (!hovered) { dwell.stop(); win.armed = true }
                }
                Timer { id: dwell; interval: Prefs.hotCornerDwell; running: hover.hovered && win.armed; onTriggered: win.run() }

                // glow: a disc centred on the corner that grows while the pointer rests there
                Rectangle {
                    id: glow
                    property real d: hover.hovered && win.armed ? win.size * 1.4 : 0
                    width: d; height: d; radius: d / 2
                    x: (win.modelData.left ? 0 : win.width) - d / 2
                    y: (win.modelData.top ? 0 : win.height) - d / 2
                    color: Theme.accent
                    opacity: hover.hovered && win.armed ? 0.35 : 0
                    Behavior on d { NumberAnimation { duration: Prefs.hotCornerDwell; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
                // ripple on firing
                Rectangle {
                    id: rip
                    property real d: 0
                    width: d; height: d; radius: d / 2
                    x: (win.modelData.left ? 0 : win.width) - d / 2
                    y: (win.modelData.top ? 0 : win.height) - d / 2
                    color: "transparent"
                    border.width: 3; border.color: Theme.accent
                    opacity: 0
                }
                ParallelAnimation {
                    id: ripple
                    NumberAnimation { target: rip; property: "d"; from: 0; to: win.size * 1.6; duration: 420; easing.type: Easing.OutQuad }
                    NumberAnimation { target: rip; property: "opacity"; from: 0.9; to: 0; duration: 420 }
                }
            }
        }
    }
}
