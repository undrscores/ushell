import QtQuick
import "../config"
import "../services"

// The focused monitor's canvas as a map: every window as a rectangle, the screen as an outline.
// Click or drag to move the camera there, scroll to zoom.
Rectangle {
    id: map
    property real pad: 600                     // canvas px of margin around the content
    implicitWidth: 340
    implicitHeight: 210
    radius: Theme.radius
    color: Theme.tint
    clip: true

    readonly property var wins: Uwc.windowsOn(Uwc.focusedMon)
    // canvas bounds: all windows plus the screen, padded
    readonly property var bounds: {
        let x0 = Uwc.viewport.x, y0 = Uwc.viewport.y
        let x1 = x0 + Uwc.viewW, y1 = y0 + Uwc.viewH
        for (const w of wins) {
            x0 = Math.min(x0, w.x); y0 = Math.min(y0, w.y)
            x1 = Math.max(x1, w.x + w.width); y1 = Math.max(y1, w.y + w.height)
        }
        return { x: x0 - pad, y: y0 - pad, w: x1 - x0 + pad * 2, h: y1 - y0 + pad * 2 }
    }
    readonly property real k: Math.min(width / bounds.w, height / bounds.h)       // map px per canvas px
    readonly property real ox: (width - bounds.w * k) / 2 - bounds.x * k
    readonly property real oy: (height - bounds.h * k) / 2 - bounds.y * k

    Repeater {
        model: map.wins
        delegate: Rectangle {
            required property var modelData
            x: map.ox + modelData.x * map.k
            y: map.oy + modelData.y * map.k
            width: Math.max(3, modelData.width * map.k)
            height: Math.max(3, modelData.height * map.k)
            radius: 2
            color: modelData.focused ? Theme.accentSoft : Theme.surfaceHi
            border.width: 1
            border.color: modelData.focused ? Theme.accent : Theme.line
        }
    }

    Rectangle {                                 // where the screen is
        x: map.ox + Uwc.viewport.x * map.k
        y: map.oy + Uwc.viewport.y * map.k
        width: Uwc.viewW * map.k
        height: Uwc.viewH * map.k
        color: "transparent"
        radius: 2
        border.width: 2
        border.color: Theme.fg
        Behavior on x { NumberAnimation { duration: Theme.animFast } }
        Behavior on y { NumberAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        function pan(m) { Uwc.centerOn((m.x - map.ox) / map.k, (m.y - map.oy) / map.k) }
        onPressed: m => pan(m)
        onPositionChanged: m => { if (pressed) pan(m) }
        onWheel: w => Uwc.zoomBy(w.angleDelta.y > 0 ? 1.15 : 1 / 1.15)
    }
}
