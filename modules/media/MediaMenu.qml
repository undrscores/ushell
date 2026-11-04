import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Dropdown under the top pill (click the media chip).
Overlay {
    id: root
    name: "media"

    Glass {
        width: 360
        height: player.implicitHeight + 40
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.margin + Theme.barHeight + 6 + (root.open ? 0 : -10)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.98
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

        MediaPlayer { id: player; x: 20; y: 20; width: parent.width - 40 }
    }
}
