import QtQuick
import "../config"

// icon + label + usage bar + detail text
Item {
    id: root
    property string icon: ""
    property string label: ""
    property real value: 0          // 0..1
    property string detail: ""
    implicitHeight: 34

    Icon { id: ic; anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 22; text: root.icon; color: Theme.fgDim }
    Column {
        anchors { left: ic.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 5
        Item {
            width: parent.width; height: txt.implicitHeight
            Text { id: txt; text: root.label; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } }
            Text { anchors.right: parent.right; text: root.detail; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
        }
        Rectangle {
            width: parent.width; height: 5; radius: 2.5
            color: Theme.hover
            Rectangle {
                height: parent.height; radius: parent.radius
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
                color: root.value > 0.85 ? Theme.danger : Theme.accent
                Behavior on width { NumberAnimation { duration: 500; easing.type: Theme.easing } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
}
