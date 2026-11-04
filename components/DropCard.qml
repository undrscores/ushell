import QtQuick
import "../config"

// Dropdown card under the top pill. Sizes itself to contentWidth/contentHeight
// (set by the owner, usually from a layout's implicit size) and animates changes.
Glass {
    id: card
    required property bool open
    property real contentWidth: 300
    property real contentHeight: 100
    property real padding: 16

    width: Math.min(contentWidth + padding * 2, parent.width - Theme.margin * 2)
    height: Math.min(contentHeight + padding * 2, parent.height - y - Theme.margin)
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.margin + Theme.barHeight + 6 + (open ? 0 : -10)
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.9
    transformOrigin: Item.Top

    Behavior on width   { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on height  { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
    Behavior on y       { NumberAnimation { duration: card.open ? 420 : 200; easing.type: card.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.4 } }
    Behavior on scale   { NumberAnimation { duration: card.open ? 420 : 200; easing.type: card.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.6 } }
}
