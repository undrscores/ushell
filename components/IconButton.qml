import QtQuick
import "../config"

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property bool active: false
    property color tone: Theme.fg
    property int size: 36
    signal clicked()

    implicitWidth: size; implicitHeight: size
    radius: Theme.radiusSmall + 2
    color: active ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : Theme.tint)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.12 : 1)
    Behavior on scale { Bounce {} }

    Icon { anchors.centerIn: parent; text: root.icon; color: root.tone }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
