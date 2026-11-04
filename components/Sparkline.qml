import QtQuick
import "../config"

// Tiny bar history graph. values: array of 0..1
Item {
    id: root
    property var values: []
    property color tone: Theme.accent
    readonly property real gapPx: 2

    Row {
        anchors.fill: parent
        spacing: root.gapPx
        Repeater {
            model: root.values.length
            delegate: Item {
                id: col
                required property int index
                readonly property real v: Math.max(0, Math.min(1, root.values[index] || 0))
                width: (root.width - root.gapPx * (root.values.length - 1)) / root.values.length
                height: root.height
                Rectangle {
                    width: parent.width
                    height: Math.max(2, parent.height * col.v)
                    anchors.bottom: parent.bottom
                    radius: Math.min(width / 2, 2)
                    color: root.tone
                    opacity: 0.35 + 0.65 * (col.index / root.values.length)
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Theme.easing } }
                }
            }
        }
    }
}
