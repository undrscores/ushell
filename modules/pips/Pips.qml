import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "../../config"
import "../../services"

// Edge markers for windows that are on this screen's canvas but outside the viewport: a dot on the
// screen edge nearest the window with an arrow pointing at it. Click-through; fades with distance.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "ushell-pips"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property var mon: Uwm.monitors.find(m => m.name === modelData.name) ?? null
        readonly property real inset: 22

        // one entry per off-screen window: edge position, arrow angle, opacity
        readonly property var pips: {
            const m = mon
            if (!m || !Prefs.offscreenPips) return []
            const z = m.viewport.zoom, W = win.width, H = win.height
            const sx = W / m.width, sy = H / m.height
            const out = []
            for (const w of Uwm.windowsOn(m)) {
                const cx = (w.x + w.width / 2 - m.viewport.x) * z * sx
                const cy = (w.y + w.height / 2 - m.viewport.y) * z * sy
                // any part of the window still visible: no pip
                const l = (w.x - m.viewport.x) * z * sx, t = (w.y - m.viewport.y) * z * sy
                if (l + w.width * z * sx > 0 && l < W && t + w.height * z * sy > 0 && t < H) continue
                const mx = W / 2, my = H / 2
                const dx = cx - mx, dy = cy - my
                const ex = mx - inset, ey = my - inset
                const s = Math.min(ex / Math.max(Math.abs(dx), 1e-6), ey / Math.max(Math.abs(dy), 1e-6))
                const dist = Math.hypot(dx, dy)
                out.push({ id: w.id, x: mx + dx * s, y: my + dy * s, angle: Math.atan2(dy, dx) * 180 / Math.PI,
                           alpha: Math.max(0.35, Math.min(1, 1.6 - dist / (Math.max(W, H) * 3))), title: w.title })
            }
            return out
        }

        Repeater {
            model: win.pips
            delegate: Item {
                id: pip
                required property var modelData
                x: modelData.x; y: modelData.y
                width: 0; height: 0
                opacity: modelData.alpha
                Behavior on x { NumberAnimation { duration: Theme.animFast } }
                Behavior on y { NumberAnimation { duration: Theme.animFast } }
                Rectangle {
                    anchors.centerIn: parent
                    width: 16; height: 16; radius: 8
                    color: Theme.surface
                    border.width: 2; border.color: Theme.accent
                }
                Shape {                                  // arrow, orbiting the dot toward the window
                    rotation: pip.modelData.angle
                    transformOrigin: Item.TopLeft
                    ShapePath {
                        fillColor: Theme.accent; strokeColor: "transparent"
                        startX: 17; startY: -5
                        PathLine { x: 26; y: 0 }
                        PathLine { x: 17; y: 5 }
                    }
                }
            }
        }
    }
}
