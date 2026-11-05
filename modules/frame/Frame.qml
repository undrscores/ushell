import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../config"

// A frame around every screen: a solid border in Theme.frameColor with rounded inner corners. The
// bar, dock and menus grow out of it. It sits on the Bottom layer, so a fullscreen window simply covers it,
// and input passes straight through. It reserves no space itself: keep niri's `gaps` at least as large as
// the frame (8 by default) so tiled windows sit inside it.
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
                color: Theme.frameColor
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
    }
}
