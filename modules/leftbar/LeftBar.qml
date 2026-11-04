import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Left auto-hiding dock: workspaces, pinned apps (with running dots), tray.
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "left"
        panelWidth: 52
        panelHeight: col.implicitHeight + 28
        panelRadius: 26

        Column {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            spacing: 10

            // Workspaces
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: Niri.workspaces
                    delegate: Item {
                        id: ws
                        required property var modelData
                        readonly property bool active: modelData.is_focused || modelData.is_active
                        width: 36; height: active ? 30 : 14
                        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutBack } }
                        Rectangle {  // glow
                            anchors.centerIn: parent
                            width: 20; height: parent.height + 4; radius: 10
                            color: Theme.accent
                            opacity: ws.active ? glowPulse : 0
                            property real glowPulse: 0.22
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                            SequentialAnimation on glowPulse {
                                running: ws.active; loops: Animation.Infinite
                                NumberAnimation { to: 0.36; duration: 1100; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.14; duration: 1100; easing.type: Easing.InOutSine }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 8; height: parent.height - 4; radius: 4
                            color: ws.active ? Theme.accent : (ws.modelData.active_window_id ? Theme.fgDim : Theme.surfaceHi)
                            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(ws.modelData.idx) }
                    }
                }
            }

            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 22; height: 1; color: Theme.line }

            // Pinned apps: click focuses the running window, or launches it
            Repeater {
                model: Config.pinnedApps
                delegate: Rectangle {
                    id: app
                    required property string modelData
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                    readonly property bool running: Niri.appWindow(entry) !== null
                    visible: entry !== null
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38; height: 38; radius: 12
                    color: ma.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    z: ma.containsMouse ? 2 : 0
                    scale: ma.pressed ? 0.9 : (ma.containsMouse ? 1.28 : 1)
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    transform: Translate { id: hop; x: 0 }
                    SequentialAnimation {
                        id: bounce
                        NumberAnimation { target: hop; property: "x"; to: 9; duration: 110; easing.type: Easing.OutQuad }
                        NumberAnimation { target: hop; property: "x"; to: 0; duration: 380; easing.type: Easing.OutBounce }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        sourceSize: Qt.size(48, 48)
                        source: app.entry ? Quickshell.iconPath(app.entry.icon, "application-x-executable") : ""
                    }
                    Rectangle {  // running indicator
                        anchors { left: parent.left; leftMargin: 1; verticalCenter: parent.verticalCenter }
                        width: 3; radius: 1.5
                        height: app.running ? 12 : 0
                        color: Theme.accent
                        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bounce.restart()
                            const w = Niri.appWindow(app.entry)
                            if (w) Niri.focusWindow(w.id)
                            else if (app.entry) app.entry.execute()
                        }
                    }
                }
            }

            Rectangle { visible: SystemTray.items.values.length > 0; anchors.horizontalCenter: parent.horizontalCenter; width: 22; height: 1; color: Theme.line }

            // Tray
            Repeater {
                model: SystemTray.items
                delegate: Rectangle {
                    id: tray
                    required property var modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38; height: 34; radius: 12
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
