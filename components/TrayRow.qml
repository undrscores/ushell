import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../config"

// System tray icons for the bar. Left click activates, right click opens the app's menu, middle click is the
// secondary action, scroll is passed through. `window` is the panel the menus open relative to.
Row {
    id: root
    required property var window
    spacing: 2
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items
        delegate: Item {
            id: t
            required property var modelData
            width: 28; height: 30
            Rectangle {
                anchors.centerIn: parent
                width: 26; height: 26; radius: 9
                color: ma.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                scale: ma.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 } }
                Image { anchors.centerIn: parent; width: 17; height: 17; source: t.modelData.icon; sourceSize: Qt.size(34, 34) }
            }
            MouseArea {
                id: ma
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onWheel: w => { if (w.angleDelta.y !== 0) t.modelData.scroll(w.angleDelta.y, false) }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || t.modelData.onlyMenu) {
                        if (t.modelData.hasMenu) {
                            const p = t.mapToItem(null, 0, t.height)
                            t.modelData.display(root.window, p.x, p.y + 6)
                        }
                    } else if (mouse.button === Qt.MiddleButton) t.modelData.secondaryActivate()
                    else t.modelData.activate()
                }
            }
        }
    }
}
