import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Dropdown under the top pill (click the clock).
Overlay {
    id: root
    name: "calendar"

    Glass {
        width: 320
        height: cal.implicitHeight + 32
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.margin + Theme.barHeight + 6 + (root.open ? 0 : -10)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: root.open ? 420 : 200; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.4 } }
        Behavior on scale   { NumberAnimation { duration: root.open ? 420 : 200; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.6 } }

        Calendar { id: cal; x: 16; y: 16; width: parent.width - 32 }
    }
}
