import QtQuick
import QtQuick.Shapes
import "../config"

// A concave corner piece where a panel meets the screen frame: a square r x r whose one corner (cx, cy,
// each 0 or r) is the point where frame and panel touch, with a quarter-circle bitten out of the opposite
// corner. It is drawn in the frame's colour so the panel looks like it grows out of the frame.
Shape {
    id: root
    property real r: 14
    property real cx: 0
    property real cy: 0
    property color color: Theme.frameColor
    width: r; height: r
    preferredRendererType: Shape.CurveRenderer

    // thin strips of the same colour just outside the two straight edges, covering anti-aliasing seams
    // against the frame and the panel
    readonly property real ov: 3
    Rectangle { color: root.color; x: root.cx === 0 ? -root.ov : root.r; y: 0; width: root.ov; height: root.r }
    Rectangle { color: root.color; y: root.cy === 0 ? -root.ov : root.r; x: 0; height: root.ov; width: root.r }

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        startX: root.cx; startY: root.cy
        PathLine { x: root.r - root.cx; y: root.cy }
        PathArc {
            x: root.cx; y: root.r - root.cy
            radiusX: root.r; radiusY: root.r
            direction: root.cx === root.cy ? PathArc.Counterclockwise : PathArc.Clockwise
        }
        PathLine { x: root.cx; y: root.cy }
    }
}
