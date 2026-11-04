import QtQuick
import "../config"

// Auto-hide toggle. Tilted pin = auto-hides; upright accent pin = always shown.
Rectangle {
    id: root
    property bool pinned: false
    signal clicked()
    implicitWidth: 30; implicitHeight: 30
    radius: 10
    color: ma.containsMouse ? Theme.hover : (pinned ? Theme.accentSoft : Theme.tint)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.12 : 1)
    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 } }

    Icon {
        anchors.centerIn: parent
        text: ""; size: 13
        color: root.pinned ? Theme.accent : Theme.fgDim
        rotation: root.pinned ? 0 : 45
        Behavior on rotation { SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.5 } }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
