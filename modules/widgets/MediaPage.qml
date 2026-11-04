import QtQuick
import "../../config"
import "../../services"
import "../../components"

Item {
    id: page
    property bool active: true
    implicitHeight: Media.available ? player.implicitHeight : empty.implicitHeight

    MediaPlayer { id: player; width: parent.width; animate: page.active }

    Rectangle {
        id: empty
        visible: !Media.available
        width: parent.width
        implicitHeight: 190
        radius: Theme.radius
        color: Theme.tint
        Column {
            anchors.centerIn: parent
            spacing: 10
            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: ""; size: 34; color: Theme.fgDim; opacity: 0.6 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing playing"; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize + 1 } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MPD, Firefox, mpv…"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } }
        }
    }
}
