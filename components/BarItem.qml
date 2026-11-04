import QtQuick
import "../config"

// Hoverable, clickable chip used in the bar.
Rectangle {
    id: root
    default property alias content: row.data
    property bool active: false
    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 30
    radius: 10
    scale: ma.pressed ? 0.94 : (ma.containsMouse ? 1.05 : 1)
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    color: (ma.containsMouse || active) ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Row { id: row; anchors.centerIn: parent; spacing: 7 }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }
}
