import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Notifications: history, quiet hours and muted apps.
ColumnLayout {
    spacing: 22

    SettingsGroup {
        title: "History"
        SettingRow {
            icon: "\uf1da"; title: "Remember notifications after a restart"
            hint: "The list in the notification centre is saved in the shell's state folder (" + Notifications.count + " now). Off keeps it in memory only."
            Switch { checked: Prefs.notificationLog; onToggled: v => Prefs.set("notificationLog", v) }
        }
    }

    SettingsGroup {
        title: "Do Not Disturb"
        SettingRow {
            icon: "\uf1f6"; title: "Do Not Disturb now"; hint: "Silences popups until you turn it off; right click the bell in the bar does the same"
            Switch { checked: Notifications.dnd; onToggled: v => Notifications.setDnd(v) }
        }
    }

    SettingsGroup {
        title: "Quiet hours"
        SettingRow {
            icon: ""; title: "Do Not Disturb on a schedule"; hint: "Popups stay quiet every day in this window; urgent ones still show"
            Switch { checked: Prefs.dndSchedule; onToggled: v => Prefs.set("dndSchedule", v) }
        }
        RowLayout {
            visible: Prefs.dndSchedule
            Layout.fillWidth: true
            Layout.leftMargin: 40
            spacing: 10
            Text { text: "From"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
            TimeField { value: Prefs.dndFrom; onEdited: v => Prefs.set("dndFrom", v) }
            Text { text: "to"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
            TimeField { value: Prefs.dndTo; onEdited: v => Prefs.set("dndTo", v) }
            Item { Layout.fillWidth: true }
        }
    }

    SettingsGroup {
        title: "Muted apps"
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            text: Prefs.mutedApps.length > 0 ? "These apps never pop up, but their notifications still reach the history. Click one to unmute it."
                                              : "No muted apps. Mute one with  qs ipc call notifications mute \"App name\"."
        }
        Flow {
            visible: Prefs.mutedApps.length > 0
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Prefs.mutedApps
                delegate: Pill { required property string modelData; label: modelData + "  "; onClicked: Notifications.unmute(modelData) }
            }
        }
    }
}
