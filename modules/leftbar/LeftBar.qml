import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Left auto-hiding dock: launcher, workspaces, pinned apps, tray.
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "left"
        panelWidth: 52
        panelHeight: col.implicitHeight + 24

        Column {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            spacing: 10

            IconButton { anchors.horizontalCenter: parent.horizontalCenter; icon: ""; onClicked: Shell.toggle("launcher") }

            // Workspaces
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: Niri.workspaces
                    delegate: Item {
                        required property var modelData
                        readonly property bool active: modelData.is_focused || modelData.is_active
                        width: 36; height: active ? 30 : 14
                        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutBack } }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 8; height: parent.height - 4; radius: 4
                            color: parent.active ? Theme.accent : (parent.modelData.active_window_id ? Theme.fgDim : Theme.surfaceHi)
                            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(parent.modelData.idx) }
                    }
                }
            }

            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 24; height: 1; color: Theme.line }

            // Pinned apps
            Repeater {
                model: Config.pinnedApps
                delegate: Rectangle {
                    id: app
                    required property string modelData
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                    visible: entry !== null
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 36; height: 36; radius: Theme.radiusSmall + 2
                    color: ma.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    scale: ma.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
                    Image {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        sourceSize: Qt.size(48, 48)
                        source: app.entry ? Quickshell.iconPath(app.entry.icon, "application-x-executable") : ""
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (app.entry) app.entry.execute() }
                }
            }

            Rectangle { visible: SystemTray.items.values.length > 0; anchors.horizontalCenter: parent.horizontalCenter; width: 24; height: 1; color: Theme.line }

            // Tray
            Repeater {
                model: SystemTray.items
                delegate: Rectangle {
                    id: tray
                    required property var modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 36; height: 32; radius: Theme.radiusSmall + 2
                    color: tma.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Image { anchors.centerIn: parent; width: 18; height: 18; source: tray.modelData.icon; sourceSize: Qt.size(36, 36) }
                    MouseArea {
                        id: tma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || tray.modelData.onlyMenu) {
                                if (tray.modelData.hasMenu) {
                                    const p = tray.mapToItem(null, tray.width, 0)
                                    tray.modelData.display(win, p.x + 6, p.y)
                                }
                            } else if (mouse.button === Qt.MiddleButton) tray.modelData.secondaryActivate()
                            else tray.modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
