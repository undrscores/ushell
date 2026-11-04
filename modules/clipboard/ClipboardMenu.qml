import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Flyout beside the left dock: clipboard history. Esc or a click outside closes it.
Overlay {
    id: root
    name: "clipboard"

    Glass {
        id: card
        width: 340
        // grows with the history, within sensible limits
        height: Math.min(parent.height * 0.7, 76 + Math.max(page.contentHeight, 150))
        x: Theme.margin * 2 + 68 + 28 + (root.open ? 0 : -24)
        y: (parent.height - height) / 2
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.88
        transformOrigin: Item.Left

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on x       { SpringAnimation { spring: card.parent && root.open ? 3.4 : 6; damping: root.open ? 0.24 : 0.8; epsilon: 0.2 } }
        Behavior on scale   { SpringAnimation { spring: root.open ? 3.4 : 6; damping: root.open ? 0.24 : 0.8; epsilon: 0.002 } }
        Behavior on height  { SpringAnimation { spring: 3.6; damping: 0.34; epsilon: 0.4 } }

        ClipboardPage {
            id: page
            x: 14; y: 14
            width: card.width - 28
            height: card.height - 28
            active: root.open
        }
    }
}
