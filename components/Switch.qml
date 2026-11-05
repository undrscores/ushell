import QtQuick
import "../config"

// Pill toggle with a springy knob.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 44; implicitHeight: 26
    radius: height / 2
    color: checked ? Theme.accent : Theme.surfaceHi
    Behavior on color { ColorAnimation { duration: Theme.animNormal } }

    Rectangle {
        id: knob
        y: 3; width: 20; height: 20; radius: 10
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.accentFg : Theme.fg
        scale: ma.pressed ? 1.2 : 1
        Behavior on x { Spring { preset: "snap"; epsilon: 0.2 } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }
    MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
}
