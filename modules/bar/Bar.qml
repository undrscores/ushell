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
        autoHide: Prefs.topAutoHide
        // dropdowns open on the focused output only, so only that screen's pill stays up
        pinned: ["quicksettings", "media", "notifications", "network"].includes(Shell.overlay)
                && (Niri.focusedOutput === "" || (win.screen !== null && win.screen.name === Niri.focusedOutput))
        panelWidth: row.implicitWidth + 20
        panelHeight: Theme.barHeight
        panelRadius: Theme.barHeight / 2

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            // Workspaces (only shown when there is more than one)
            Workspaces { id: wsRow; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { visible: wsRow.visible; width: 1; height: 16; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }

            // Clock
            Row {
                spacing: 7
                leftPadding: 9; rightPadding: 9
                anchors.verticalCenter: parent.verticalCenter
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

            // Tray
            Rectangle { visible: tray.visible; width: 1; height: 16; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
            TrayRow { id: tray; window: win; anchors.verticalCenter: parent.verticalCenter }

            // Timer (only while one is running or paused) → Focus tab
            Rectangle { visible: timerItem.visible; width: 1; height: 16; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
            BarItem {
                id: timerItem
                visible: Countdown.active
                onClicked: { Shell.widgetsTab = 2; Shell.widgetsPinned = true }
                Icon { text: "\uf017"; color: Countdown.running ? Theme.accent : Theme.fgDim; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: Countdown.fmt(Countdown.remaining)
                    color: Countdown.running ? Theme.fg : Theme.fgDim
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
                        NumberAnimation { target: volIcon; property: "scale"; to: 1.45; duration: 80; easing.type: Easing.OutQuad }
                        NumberAnimation { target: volIcon; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.3; easing.period: 0.4 }
                    }
                    SequentialAnimation {   // mute: little head-shake
                        id: shake
                        NumberAnimation { target: volIcon; property: "rotation"; to: -18; duration: 70 }
                        NumberAnimation { target: volIcon; property: "rotation"; to: 16;  duration: 90 }
                        NumberAnimation { target: volIcon; property: "rotation"; to: -8;  duration: 80 }
                        NumberAnimation { target: volIcon; property: "rotation"; to: 0;   duration: 100 }
                    }
                    Connections {
                        target: Audio
                        function onVolumeChanged() { bump.restart() }
                        function onMutedChanged() { bump.restart(); shake.restart() }
                    }
                }
                Text {
                    text: Math.round(Audio.volume * 100)
                    color: Audio.muted ? Theme.danger : Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Keyboard layout (only when there is more than one) and the mic privacy dot
            BarItem {
                visible: Niri.layouts.length > 1
                Text {
                    text: Niri.layoutShort
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            BarItem {
                visible: Audio.micInUse
                active: Shell.overlay === "quicksettings"
                onClicked: Shell.toggle("quicksettings")
                Icon {
                    text: Audio.micMuted ? "\uf131" : "\uf130"
                    color: Audio.micMuted ? Theme.fgDim : Theme.danger
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Network → connections (hidden when NetworkManager is not there)
            BarItem {
                visible: Network.available
                active: Shell.overlay === "network"
                onClicked: Shell.toggle("network")
                Icon { text: Network.glyph; color: Network.dim ? Theme.danger : Theme.fgDim; anchors.verticalCenter: parent.verticalCenter }
            }

            // Notifications → history (right click: Do Not Disturb)
            BarItem {
                active: Shell.overlay === "notifications"
                onClicked: mouse => { if (mouse.button === Qt.RightButton) Notifications.toggleDnd(); else Shell.toggle("notifications") }
                Icon {
                    text: Notifications.silent ? "\uf1f6" : "\uf0f3"
                    color: Notifications.silent ? Theme.danger : Theme.fgDim
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    visible: Notifications.unread > 0
                    text: Notifications.unread
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Settings
            BarItem {
                active: Shell.settingsOpen
                onClicked: Shell.toggle("settings")
                Icon { text: "\uf013"; color: Theme.fgDim; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
