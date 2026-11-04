import QtQuick
import "../config"

// value is 0..1 and is owned by the caller; the slider only emits moved().
Item {
    id: root
    property real value: 0
    property color tone: Theme.accent
    signal moved(real value)
    implicitHeight: 24

    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        width: parent.width; height: 6; radius: 3
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.hover
        Rectangle {
            height: parent.height; radius: 3
            width: Math.max(height, track.width * root.clamped)
            color: root.tone
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
        }
    }
    Rectangle {
        width: 14; height: 14; radius: 7
        color: Theme.fg
        anchors.verticalCenter: parent.verticalCenter
        x: (track.width - width) * root.clamped
        scale: ma.pressed ? 1.2 : (ma.containsMouse ? 1.1 : 1)
        Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x) }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.clamped + (w.angleDelta.y > 0 ? 0.03 : -0.03))))
    }
}
