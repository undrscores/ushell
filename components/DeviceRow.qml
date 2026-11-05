import QtQuick
import "../config"

// A selectable list row, with a tick on the current one (audio output / input devices).
Rectangle {
    id: root
    property string label: ""
    property bool current: false
    signal clicked()

    height: 36
    radius: Theme.radiusSmall + 2
    color: current ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        anchors { left: parent.left; leftMargin: 12; right: tick.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: root.label
        color: root.current ? Theme.fg : Theme.fgDim
        font { family: Theme.font; pixelSize: Theme.fontSize }
    }
    Icon { id: tick; visible: root.current; text: ""; size: 12; color: Theme.accent
           anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
