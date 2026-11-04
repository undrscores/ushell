import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"

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

        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
        SystemClock { id: clock; precision: SystemClock.Minutes }

        Rectangle {
            id: pill
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.surface
            border.width: 1

            // Entrance animation
            opacity: 0
            Component.onCompleted: { opacity = 1 }
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }

            // Left: workspaces
            Row {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
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

            // Center: focused window title
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width * 0.4)
                elide: Text.ElideRight
                text: Niri.title
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }

            // Right: volume + clock
            Row {
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 16
                Text {
                    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                    text: audio ? (audio.muted ? "muted" : "vol " + Math.round(audio.volume * 100) + "%") : "no audio"
                    color: audio && audio.muted ? Theme.danger : Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                }
            }
        }
    }
}
