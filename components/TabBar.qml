import QtQuick
import "../config"

// Pill tab strip with a sliding highlight.   tabs: [{ icon, label }]
Item {
    id: root
    property var tabs: []
    property int current: 0
    signal selected(int index)
    implicitHeight: 40

    readonly property real tabW: (width - 6) / Math.max(1, tabs.length)

    Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.tint }

    Rectangle {
        id: indicator
        y: 3; height: parent.height - 6
        width: root.tabW
        x: 3 + root.current * root.tabW
        radius: height / 2
        color: Theme.accentSoft
        border { width: 1; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) }
        Behavior on x { SpringAnimation { spring: 4.5; damping: 0.28; epsilon: 0.3 } }
    }

    Repeater {
        model: root.tabs
        delegate: Item {
            id: tab
            required property var modelData
            required property int index
            readonly property bool on: root.current === index
            x: 3 + index * root.tabW; y: 0
            width: root.tabW; height: root.height
            scale: ma.pressed ? 0.95 : 1
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Theme.easing } }

            Row {
                anchors.centerIn: parent
                spacing: 7
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.icon; size: 15
                    color: tab.on ? Theme.accent : (ma.containsMouse ? Theme.fg : Theme.fgDim)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.label
                    color: tab.on ? Theme.fg : (ma.containsMouse ? Theme.fg : Theme.fgDim)
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: tab.on }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selected(tab.index) }
        }
    }

    // wheel over the strip flips tabs
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            if (wheelCool.running) return
            const d = (Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y) < 0 ? 1 : -1
            const t = Math.max(0, Math.min(root.tabs.length - 1, root.current + d))
            if (t !== root.current) { root.selected(t); wheelCool.restart() }
        }
    }
    Timer { id: wheelCool; interval: 260 }
}
