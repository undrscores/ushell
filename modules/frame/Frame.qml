import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../config"

// A frame around every screen: a solid border in the panel colour with rounded inner corners. The
// bar, dock and menus grow out of it. It sits on the Bottom layer, so tiled windows are cut off by
// the frame's reserved edges while a fullscreen window simply covers it. Input passes straight through.
Variants {
    model: Theme.frame > 0 ? Quickshell.screens : []

    Scope {
        id: scope
        required property var modelData

        // the visible frame
        PanelWindow {
            screen: scope.modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "ushell-frame"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskInverted: true
                    maskSource: cutout
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }
            // the hole the windows show through
            Item {
                id: cutout
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    x: Theme.frame; y: Theme.frame
                    width: parent.width - Theme.frame * 2
                    height: parent.height - Theme.frame * 2
                    radius: Theme.frameRadius
                }
            }
        }

        // One thin invisible window per edge reserves the frame's space, so tiled windows stay inside it.
        Variants {
            model: [
                { top: true,  left: true,  right: true  },
                { bottom: true, left: true, right: true },
                { left: true, top: true,   bottom: true },
                { right: true, top: true,  bottom: true }
            ]
            PanelWindow {
                required property var modelData
                screen: scope.modelData
                anchors { top: modelData.top === true; bottom: modelData.bottom === true; left: modelData.left === true; right: modelData.right === true }
                implicitWidth: Theme.frame
                implicitHeight: Theme.frame
                exclusionMode: ExclusionMode.Normal
                color: "transparent"
                mask: Region {}
                WlrLayershell.namespace: "ushell-frame-edge"
                WlrLayershell.layer: WlrLayer.Bottom
            }
        }
    }
}
