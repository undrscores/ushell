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
        pinned: ["quicksettings", "calendar", "power"].includes(Shell.overlay)
        panelWidth: row.implicitWidth + 16
        panelHeight: Theme.barHeight

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 2

            BarItem {
                onClicked: Shell.toggle("launcher")
                Icon { text: ""; anchors.verticalCenter: parent.verticalCenter }
            }

            BarItem {
                active: Shell.overlay === "calendar"
                onClicked: Shell.toggle("calendar")
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            BarItem {
                visible: Media.available
                onClicked: Media.toggle()
                Icon { text: Media.playing ? "" : ""; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    width: Math.min(implicitWidth, 150); elide: Text.ElideRight
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
                active: Shell.overlay === "power"
                onClicked: Shell.toggle("power")
                Icon { text: ""; color: Theme.fgDim; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
