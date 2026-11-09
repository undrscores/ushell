import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// General: which panels exist and how they behave.
ColumnLayout {
    spacing: 22

    SettingsGroup {
        title: "Modes"
        SettingRow {
            icon: "\uf06e"; title: "Focus mode"; hint: "Silences notifications and hides the now-playing capsule and radial menu"
            Switch { checked: Prefs.focusMode; onToggled: v => Prefs.set("focusMode", v) }
        }
        SettingRow {
            icon: "\uf186"; title: "Night light"
            hint: NightLight.available ? (NightLight.failed ? "wlsunset quit straight away; does your compositor support it?" : "A warm tint for the evening, done by wlsunset")
                                       : "Install wlsunset to use this"
            Switch { enabled: NightLight.available; checked: Prefs.nightLight; onToggled: v => Prefs.set("nightLight", v) }
        }
        SettingRow {
            visible: NightLight.available
            icon: "\uf2c9"; title: "Night light warmth"; hint: "Lower is warmer"
            Row {
                spacing: 4
                Repeater {
                    model: [3000, 4000, 5000]
                    delegate: Pill { required property int modelData; label: modelData + "K"; active: Prefs.nightTemp === modelData
                                     onClicked: Prefs.set("nightTemp", modelData) }
                }
            }
        }
    }

    SettingsGroup {
        title: "Security"
        SettingRow {
            icon: "\uf023"; title: "Password prompt for admin actions"
            hint: !Prefs.polkitAgent ? "Off: start another polkit agent (e.g. polkit-gnome) or privileged actions will fail"
                  : Auth.registered ? "ushell asks for your password when a program needs more rights (pkexec, VPN, network settings)"
                  : "Could not register as the polkit agent. Stop any other agent (polkit-gnome, polkit-kde) and reload."
            Switch { checked: Prefs.polkitAgent; onToggled: v => Prefs.set("polkitAgent", v) }
        }
    }

    SettingsGroup {
        title: "Screenshots and recording"
        SettingRow {
            icon: "\uf017"; title: "Delay before capturing"; hint: "Gives you time to open a menu or move the pointer"
            Row {
                spacing: 4
                Repeater {
                    model: [0, 3, 5, 10]
                    delegate: Pill { required property int modelData; label: modelData === 0 ? "None" : modelData + "s"; active: Prefs.captureDelay === modelData
                                     onClicked: Prefs.set("captureDelay", modelData) }
                }
            }
        }
        SettingRow {
            icon: "\uf028"; title: "Record sound"; hint: Capture.canRecord ? "Screen recordings include what the speakers play" : "Install wf-recorder (and slurp for regions) to record the screen"
            Switch { enabled: Capture.canRecord; checked: Prefs.recordAudio; onToggled: v => Prefs.set("recordAudio", v) }
        }
        SettingRow {
            icon: "\uf07c"; title: "Recordings folder"; hint: Config.recordingDir + "  (change recordingDir in config.json)"
            Pill { label: "Open"; onClicked: Capture.openFolder() }
        }
    }

    SettingsGroup {
        title: "Bar"
        SettingRow {
            icon: ""; title: "Auto-hide the top bar"; hint: "Off keeps it visible and reserves its space"
            Switch { checked: Prefs.topAutoHide; onToggled: v => Prefs.set("topAutoHide", v) }
        }
    }

    SettingsGroup {
        title: "Screen"
        SettingRow {
            icon: ""; title: "Now-playing capsule"; hint: "Slides up at the bottom left on hover and when the track changes"
            Switch { checked: Prefs.mediaCapsule; onToggled: v => Prefs.set("mediaCapsule", v) }
        }
        SettingRow {
            icon: ""; title: "Radial menu"; hint: "Quick actions from the bottom right corner"
            Switch { checked: Prefs.radialMenu; onToggled: v => Prefs.set("radialMenu", v) }
        }
    }
}
