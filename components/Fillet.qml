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
    property color color: Theme.bg
    width: r; height: r
    preferredRendererType: Shape.CurveRenderer

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
