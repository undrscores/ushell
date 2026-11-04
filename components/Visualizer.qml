import QtQuick
import "../config"
import "../services"

// Cava spectrum bars, anchored to the bottom.
Item {
    id: root
    property color tone: Theme.accent
    implicitHeight: 44
    readonly property int n: Cava.count
    readonly property real gapPx: 3

    Row {
        anchors.fill: parent
        spacing: root.gapPx
        Repeater {
            model: Cava.bars
            delegate: Item {
                required property var modelData
                width: (root.width - root.gapPx * (root.n - 1)) / root.n
                height: root.height
                Rectangle {
                    width: parent.width
                    height: Math.max(3, parent.height * Math.min(1, parent.modelData / 100))
                    anchors.bottom: parent.bottom
                    radius: width / 2
                    color: root.tone
                    opacity: 0.55 + 0.45 * Math.min(1, parent.modelData / 100)
                    Behavior on height { NumberAnimation { duration: 70 } }
                }
            }
        }
    }
}
