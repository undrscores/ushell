import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Zoomed far out, windows are too small to read: draw each one's icon and title over it. Fades in
// below Prefs.overviewZoom (and out again as you zoom back in). Click-through, so the compositor still
// gets every click.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "ushell-overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property var mon: Uwc.monitors.find(m => m.name === modelData.name) ?? null
        readonly property real z: mon ? mon.viewport.zoom : 1
        readonly property real amount: Prefs.overviewLabels ? Math.max(0, Math.min(1, (Prefs.overviewZoom - z) / (Prefs.overviewZoom * 0.3))) : 0
        visible: amount > 0.01

        Repeater {
            model: win.visible ? Uwc.windowsOn(win.mon) : []
            delegate: Item {
                id: lab
                required property var modelData
                readonly property real sx: win.width / win.mon.width
                readonly property real sy: win.height / win.mon.height
                x: (modelData.x - win.mon.viewport.x) * win.z * sx
                y: (modelData.y - win.mon.viewport.y) * win.z * sy
                width: modelData.width * win.z * sx
                height: modelData.height * win.z * sy
                clip: true
                opacity: win.amount
                visible: width > 56 && height > 40 && x + width > 0 && x < win.width && y + height > 0 && y < win.height

                readonly property var entry: modelData.app_id ? DesktopEntries.heuristicLookup(modelData.app_id) : null
                readonly property real iconSize: Math.max(24, Math.min(72, Math.min(width, height) * 0.4))

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.35)
                    radius: 6
                }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 6
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lab.iconSize; height: lab.iconSize
                        sourceSize: Qt.size(lab.iconSize * 2, lab.iconSize * 2)
                        source: lab.entry && lab.entry.icon ? Quickshell.iconPath(lab.entry.icon, true) : ""
                        visible: status === Image.Ready
                        asynchronous: true
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        text: lab.modelData.title || lab.modelData.app_id || ""
                        color: "white"
                        font { family: Theme.font; pixelSize: Math.max(12, Math.min(22, lab.iconSize * 0.35)); bold: true }
                    }
                }
            }
        }
    }
}
