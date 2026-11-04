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
        height: player.implicitHeight + 12
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.margin + Theme.barHeight + 6 + (root.open ? 0 : -10)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: root.open ? 420 : 200; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.4 } }
        Behavior on scale   { NumberAnimation { duration: root.open ? 420 : 200; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.6 } }

        MediaPlayer { id: player; x: 6; y: 6; width: parent.width - 12 }
    }
}
