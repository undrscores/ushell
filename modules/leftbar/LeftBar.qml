import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Left side, full height: workspaces, Apps / Clipboard tabs, tray.
// Auto-hides by default; the pin button keeps it always visible (and reserves its space).
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "left"
        autoHide: Prefs.leftAutoHide
        takesFocus: true
        panelWidth: 300
        panelHeight: modelData.height
        panelRadius: Theme.radius + 4

        readonly property var tabs: [
            { icon: "", label: "Apps" },
            { icon: "", label: "Clipboard" }
        ]

        Item {
            id: body
            anchors.fill: parent
            readonly property int pad: 16

            // header: workspaces + pin
            Item {
                id: header
                x: body.pad; y: body.pad
                width: parent.width - body.pad * 2
                height: 30

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: Niri.workspaces
                        delegate: Item {
                            id: ws
                            required property var modelData
                            readonly property bool active: modelData.is_focused || modelData.is_active
                            width: active ? 34 : 14; height: 26
                            Behavior on width { SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.3 } }
                            Rectangle {   // glow
                                anchors.centerIn: parent
                                width: parent.width + 8; height: 18; radius: 9
                                color: Theme.accent
                                opacity: ws.active ? 0.2 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 4; height: 10; radius: 5
                                color: ws.active ? Theme.accent : (ws.modelData.active_window_id ? Theme.fgDim : Theme.surfaceHi)
                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(ws.modelData.idx) }
                        }
                    }
                }
                PinButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    pinned: !Prefs.leftAutoHide
                    onClicked: Prefs.toggle("left")
                }
            }

            TabBar {
                id: bar
                x: body.pad; y: header.y + header.height + 14
                width: parent.width - body.pad * 2
                tabs: win.tabs
                current: Shell.leftTab
                onSelected: i => Shell.leftTab = i
            }

            // footer: tray
            Item {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: tray.count > 0 ? 58 : body.pad
                Behavior on height { NumberAnimation { duration: 250; easing.type: Theme.easing } }
                Rectangle { visible: tray.count > 0; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: body.pad; rightMargin: body.pad } height: 1; color: Theme.line }
                Row {
                    id: tray
                    readonly property int count: SystemTray.items.values.length
                    anchors { left: parent.left; leftMargin: body.pad; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 }
                    spacing: 4
                    Repeater {
                        model: SystemTray.items
                        delegate: Rectangle {
                            id: t
                            required property var modelData
                            width: 36; height: 36; radius: 12
                            color: tma.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            scale: tma.containsMouse ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 } }
                            Image { anchors.centerIn: parent; width: 20; height: 20; source: t.modelData.icon; sourceSize: Qt.size(40, 40) }
                            MouseArea {
                                id: tma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton || t.modelData.onlyMenu) {
                                        if (t.modelData.hasMenu) {
                                            const p = t.mapToItem(null, t.width, 0)
                                            t.modelData.display(win, p.x + 6, p.y)
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) t.modelData.secondaryActivate()
                                    else t.modelData.activate()
                                }
                            }
                        }
                    }
                }
            }

            Pager {
                id: pager
                x: body.pad; y: bar.y + bar.height + 14
                width: parent.width - body.pad * 2
                height: footer.y - y - 8
                index: Shell.leftTab
                count: win.tabs.length
                onSwiped: i => Shell.leftTab = i

                AppsPage      { width: pager.width; height: pager.height }
                ClipboardPage { width: pager.width; height: pager.height }
            }
        }
    }
}
