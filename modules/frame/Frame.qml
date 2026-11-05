import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../components"
import "../../config"

// A frame around every screen: a solid border in Theme.frameColor with rounded inner corners. The
// bar, dock and menus grow out of it. It sits on the Top layer, above windows (their shadows and borders would otherwise tint it), with a
// transparent hole for them to show through; a fullscreen window still covers it, and input passes straight through. It reserves no space itself: keep niri's `gaps` at least as large as
// the frame (8 by default) so tiled windows sit inside it.
Variants {
    model: Theme.frame > 0 ? Quickshell.screens : []

    Scope {
        id: scope
        required property var modelData

        // the visible frame
        PanelWindow {
            id: fwin
            screen: scope.modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "ushell-frame"
            WlrLayershell.layer: WlrLayer.Top      // above windows, so their shadows and borders never tint it
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // four straight bands plus a concave Fillet in each corner: solid and crisp, no masks
            readonly property real f: Theme.frame
            readonly property real r: Theme.frameRadius
            Rectangle { x: 0; y: 0; width: fwin.width; height: fwin.f; color: Theme.frameColor }
            Rectangle { x: 0; y: fwin.height - fwin.f; width: fwin.width; height: fwin.f; color: Theme.frameColor }
            Rectangle { x: 0; y: fwin.f; width: fwin.f; height: fwin.height - fwin.f * 2; color: Theme.frameColor }
            Rectangle { x: fwin.width - fwin.f; y: fwin.f; width: fwin.f; height: fwin.height - fwin.f * 2; color: Theme.frameColor }
            Fillet { r: fwin.r; x: fwin.f;                      y: fwin.f;                      cx: 0;   cy: 0 }
            Fillet { r: fwin.r; x: fwin.width - fwin.f - r;   y: fwin.f;                      cx: r;   cy: 0 }
            Fillet { r: fwin.r; x: fwin.f;                      y: fwin.height - fwin.f - r;  cx: 0;   cy: r }
            Fillet { r: fwin.r; x: fwin.width - fwin.f - r;   y: fwin.height - fwin.f - r;  cx: r;   cy: r }
        }
    }
}
