import QtQuick
import "../config"
import "../services"

// Cava spectrum: gradient bars + slowly falling peak caps.
Item {
    id: root
    implicitHeight: 56
    readonly property int n: Cava.count
    readonly property real gapPx: 3
    property var peaks: new Array(n).fill(0)

    Connections {
        target: Cava
        function onBarsChanged() {
            const p = root.peaks.slice()
            for (let i = 0; i < p.length; i++) p[i] = Math.max(Cava.bars[i] || 0, p[i] - 1.1)
            root.peaks = p
        }
    }

    Row {
        anchors.fill: parent
        spacing: root.gapPx
        Repeater {
            model: root.n
            delegate: Item {
                id: bar
                required property int index
                readonly property real v: Math.min(1, (Cava.bars[index] || 0) / 100)
                readonly property real pk: Math.min(1, (root.peaks[index] || 0) / 100)
                width: (root.width - root.gapPx * (root.n - 1)) / root.n
                height: root.height

                Rectangle {
                    width: parent.width
                    height: Math.max(4, parent.height * bar.v)
                    anchors.bottom: parent.bottom
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.accent2 }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
                Rectangle {  // peak cap
                    width: parent.width; height: 2; radius: 1
                    color: Theme.accent2
                    opacity: bar.pk > 0.04 ? 0.85 : 0
                    y: parent.height - Math.max(4, parent.height * bar.pk) - 4
                }
            }
        }
    }
}
