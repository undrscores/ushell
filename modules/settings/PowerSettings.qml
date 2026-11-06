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
        title: "Battery and power profile"
        Text {
            visible: !Power.hasBattery && !Power.profileAvailable
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            text: "No battery was found, and no power-profiles-daemon. Install power-profiles-daemon to switch between power saver, balanced and performance."
        }
        SettingRow {
            visible: Power.hasBattery
            icon: Power.glyph; title: "Battery " + Power.level + "%"
            hint: Power.timeText + (Power.health >= 0 ? (Power.timeText !== "" ? "  ·  " : "") + "health " + Power.health + "%" : "")
            Item {}
        }
        SettingRow {
            visible: Power.hasBattery
            icon: "\uf071"; title: "Warn when the battery gets low"; hint: "Shows a message at this charge level while on battery"
            Row {
                spacing: 4
                Repeater {
                    model: [0, 10, 15, 20, 30]
                    delegate: Pill { required property int modelData; label: modelData === 0 ? "Off" : modelData + "%"; active: Prefs.batteryWarnPct === modelData
                                     onClicked: Prefs.set("batteryWarnPct", modelData) }
                }
            }
        }
        SettingRow {
            visible: Power.hasBattery && Power.profileAvailable
            icon: "\uf06c"; title: "Switch to power saver when low"; hint: "Goes back to the previous profile once the charger is plugged in"
            Switch { checked: Prefs.autoPowerSaver; onToggled: v => Prefs.set("autoPowerSaver", v) }
        }
        SettingRow {
            visible: Power.profileAvailable
            icon: "\uf0e4"; title: "Power profile"; hint: "Also in Quick Settings; `qs ipc call power cycle` from a key"
            Row {
                spacing: 4
                Repeater {
                    model: Power.offered
                    delegate: Pill { required property var modelData; label: modelData.title; active: Power.current.id === modelData.id
                                     onClicked: Power.setProfile(modelData.id) }
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
