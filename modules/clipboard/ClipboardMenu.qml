import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Clipboard history, centred on the screen (radial menu, launcher or `qs ipc call shell toggle clipboard`).
// Esc or a click outside closes it.
Overlay {
    id: root
    name: "clipboard"
    scrim: 0.3

    Glass {
        id: card
        width: 340
        // grows with the history, within sensible limits
        height: Math.min(parent.height * 0.7, 76 + Math.max(page.contentHeight, 150))
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 + (root.open ? 0 : -14)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.88
        transformOrigin: Item.Center

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { Spring { preset: root.open ? "popIn" : "popOut"; epsilon: 0.002 } }
        Behavior on height  { Spring { preset: "settle"; epsilon: 0.4 } }

        ClipboardPage {
            id: page
            x: 14; y: 14
            width: card.width - 28
            height: card.height - 28
            active: root.open
        }
    }
}
