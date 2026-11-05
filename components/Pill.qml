import QtQuick
import "../config"

// Small rounded text button.
Rectangle {
    id: pill
    property string label
    property bool active: false          // highlighted (e.g. the current choice)
    signal clicked()
    implicitWidth: text.implicitWidth + 24
    implicitHeight: 28
    radius: height / 2
    color: active ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : Theme.tint)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    scale: ma.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
    Text {
        id: text
        anchors.centerIn: parent
        text: pill.label
        color: pill.active ? Theme.accent : Theme.fg
        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
}
