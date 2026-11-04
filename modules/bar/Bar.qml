import Quickshell
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Top-middle auto-hiding pill. Its menus drop down beneath it.
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "top"
        pinned: ["quicksettings", "calendar", "media", "power"].includes(Shell.overlay)
        panelWidth: row.implicitWidth + 20
        panelHeight: Theme.barHeight
        panelRadius: Theme.barHeight / 2

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            // Clock → calendar
            BarItem {
                active: Shell.overlay === "calendar"
                onClicked: Shell.toggle("calendar")
                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 1; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Now playing → media player
            Rectangle { visible: Media.available; width: 1; height: 16; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
            BarItem {
                visible: Media.available
                active: Shell.overlay === "media"
                onClicked: Shell.toggle("media")
                Rectangle {
                    width: 20; height: 20; radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.tint
                    clip: true
                    Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
                Text {
                    width: Math.min(implicitWidth, 150); elide: Text.ElideRight
                    text: Media.title
                    color: Media.playing ? Theme.fg : Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Volume → quick settings
            Rectangle { width: 1; height: 16; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
            BarItem {
                active: Shell.overlay === "quicksettings"
                onClicked: Shell.toggle("quicksettings")
                onScrolled: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.03 : -0.03))
                Icon {
                    id: volIcon
                    text: Audio.icon(); color: Audio.muted ? Theme.danger : Theme.fg; anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation {
                        id: bump
                        NumberAnimation { target: volIcon; property: "scale"; to: 1.35; duration: 90; easing.type: Easing.OutQuad }
                        NumberAnimation { target: volIcon; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack }
                    }
                    Connections { target: Audio; function onVolumeChanged() { bump.restart() } function onMutedChanged() { bump.restart() } }
                }
                Text {
                    text: Math.round(Audio.volume * 100)
                    color: Audio.muted ? Theme.danger : Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Power
            BarItem {
                active: Shell.overlay === "power"
                onClicked: Shell.toggle("power")
                Icon { text: ""; color: Theme.fgDim; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
