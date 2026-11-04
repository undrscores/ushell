import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../../config"
import "../../services"
import "../../components"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        anchors { top: true; left: true; right: true }
        margins { top: Theme.margin; left: Theme.margin; right: Theme.margin }
        implicitHeight: Theme.barHeight
        exclusiveZone: Theme.barHeight
        color: "transparent"

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.glass
            border { color: Theme.line; width: 1 }

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }

            // ── Left: workspaces ─────────────────────────────
            Row {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 6
                Repeater {
                    model: Niri.workspaces
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.is_focused || modelData.is_active
                        width: active ? 28 : 10
                        height: 10
                        radius: 5
                        color: active ? Theme.accent : (modelData.active_window_id ? Theme.fgDim : Theme.surfaceHi)
                        Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Niri.focusWorkspace(modelData.idx)
                        }
                    }
                }
            }

            // ── Center: focused window ───────────────────────
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width * 0.35)
                elide: Text.ElideRight
                text: Niri.title
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }

            // ── Right: tray, media, audio, clock, power ──────
            Row {
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 2

                Repeater {
                    model: SystemTray.items
                    delegate: BarItem {
                        id: trayItem
                        required property var modelData
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                if (modelData.hasMenu) {
                                    const p = trayItem.mapToItem(null, 0, trayItem.height)
                                    modelData.display(win, p.x, p.y + 4)
                                }
                            } else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
                            else modelData.activate()
                        }
                        Image {
                            width: 16; height: 16
                            source: trayItem.modelData.icon
                            sourceSize: Qt.size(32, 32)
                        }
                    }
                }

                BarItem {
                    visible: Media.available
                    onClicked: Media.toggle()
                    Icon { text: Media.playing ? "" : ""; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        width: Math.min(implicitWidth, 160); elide: Text.ElideRight
                        text: Media.title
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                BarItem {
                    active: Shell.overlay === "quicksettings"
                    onClicked: Shell.toggle("quicksettings")
                    onScrolled: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.03 : -0.03))
                    Icon { text: Audio.icon(); color: Audio.muted ? Theme.danger : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: Math.round(Audio.volume * 100) + "%"
                        color: Audio.muted ? Theme.danger : Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                BarItem {
                    active: Shell.overlay === "sidebar"
                    onClicked: Shell.toggle("sidebar")
                    Text {
                        text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                BarItem {
                    active: Shell.overlay === "power"
                    onClicked: Shell.toggle("power")
                    Icon { text: ""; color: Theme.fgDim; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
