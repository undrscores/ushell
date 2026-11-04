import QtQuick
import "../config"
import "../services"

Column {
    spacing: 12
    Repeater {
        model: [
            { icon: "", v: Stats.cpu },
            { icon: "\uDB80\uDF5B", v: Stats.mem }
        ]
        delegate: Row {
            id: stat
            required property var modelData
            width: parent.width
            spacing: 12
            Icon { anchors.verticalCenter: parent.verticalCenter; text: stat.modelData.icon; color: Theme.fgDim; width: 20 }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 - 48 - 24; height: 6; radius: 3
                color: Theme.hover
                Rectangle {
                    height: parent.height; radius: 3
                    width: Math.max(height, parent.width * stat.modelData.v)
                    color: stat.modelData.v > 0.85 ? Theme.danger : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 48; horizontalAlignment: Text.AlignRight
                text: Math.round(stat.modelData.v * 100) + "%"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }
    }
}
