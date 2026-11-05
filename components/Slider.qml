import QtQuick
import "../config"

// value is 0..1 and is owned by the caller; the slider only emits moved().
Item {
    id: root
    property real value: 0
    property color tone: Theme.accent
    signal moved(real value)         // continuously while dragging / scrolling
    signal released(real value)      // once, with the final value, when the pointer is let go
    property real lastMoved: 0
    readonly property bool pressed: ma.pressed
    implicitHeight: 24

    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        width: parent.width; height: ma.containsMouse || ma.pressed ? 8 : 6; radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.hover
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
        Rectangle {
            height: parent.height; radius: height / 2
            width: Math.max(height, track.width * root.clamped)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.tone }
                GradientStop { position: 1; color: Qt.lighter(root.tone, 1.25) }
            }
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        }
    }
    // handle + glow ring
    Item {
        id: handle
        width: 16; height: 16
        anchors.verticalCenter: parent.verticalCenter
        x: (track.width - width) * root.clamped
        Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Rectangle {
            anchors.centerIn: parent
            width: ma.pressed ? 30 : (ma.containsMouse ? 24 : 0); height: width; radius: width / 2
            color: root.tone; opacity: 0.22
            Behavior on width { Pop { duration: Theme.animNormal; overshoot: 1.7 } }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 14; height: 14; radius: 7
            color: Theme.fg
            scale: ma.pressed ? 1.3 : (ma.containsMouse ? 1.15 : 1)
            Behavior on scale { Bounce { duration: Theme.animSlow } }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function emit(v) { root.lastMoved = v; root.moved(v) }
        function set(x) { emit(Math.max(0, Math.min(1, x / width))) }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x) }
        onReleased: root.released(root.lastMoved)
        onWheel: w => emit(Math.max(0, Math.min(1, root.clamped + (w.angleDelta.y > 0 ? 0.03 : -0.03))))
    }
}
