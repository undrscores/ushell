import QtQuick
import "../config"

// Dropdown card under the top pill. Sizes itself to contentWidth/contentHeight
// (set by the owner, usually from a layout's implicit size) and animates changes.
Glass {
    id: card
    required property bool open
    property real contentWidth: 300
    property real contentHeight: 100
    property real padding: 18
    shadow: true

    width: Math.min(contentWidth + padding * 2, parent.width - Theme.margin * 2)
    height: Math.min(contentHeight + padding * 2, parent.height - y - Theme.margin)
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.margin + Theme.barHeight + 6 + (open ? 0 : -18)
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.8
    transformOrigin: Item.Top

    Behavior on width   { SpringAnimation { spring: 3.6; damping: 0.34; epsilon: 0.4 } }
    Behavior on height  { SpringAnimation { spring: 3.6; damping: 0.34; epsilon: 0.4 } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
    Behavior on y       { SpringAnimation { spring: card.open ? 3.4 : 6; damping: card.open ? 0.24 : 0.8; epsilon: 0.2 } }
    Behavior on scale   { SpringAnimation { spring: card.open ? 3.4 : 6; damping: card.open ? 0.22 : 0.8; epsilon: 0.002 } }
}
