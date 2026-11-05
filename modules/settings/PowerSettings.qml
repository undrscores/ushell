import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Power and idle: when the screen locks and turns off.
ColumnLayout {
    spacing: 22

    SettingsGroup {
        title: "When idle"
        SettingRow {
            icon: ""; title: "Lock after"; hint: "Of no keyboard or mouse use; a playing video holds it back"
            Row {
                spacing: 4
                Repeater {
                    model: [0, 5, 10, 30]
                    delegate: Pill { required property int modelData; label: modelData === 0 ? "Off" : modelData + "m"; active: Prefs.idleLockMin === modelData
                                     onClicked: Prefs.set("idleLockMin", modelData) }
                }
            }
        }
        SettingRow {
            icon: ""; title: "Turn the screens off after"
            Row {
                spacing: 4
                Repeater {
                    model: [0, 5, 15, 30]
                    delegate: Pill { required property int modelData; label: modelData === 0 ? "Off" : modelData + "m"; active: Prefs.idleOffMin === modelData
                                     onClicked: Prefs.set("idleOffMin", modelData) }
                }
            }
        }
    }

    SettingsGroup {
        title: "Right now"
        SettingRow {
            icon: ""; title: "Keep awake"; hint: "No lock or screen-off until you turn it off or restart the shell"
            Switch { checked: Idle.keepAwake; onToggled: v => Idle.keepAwake = v }
        }
    }
}
