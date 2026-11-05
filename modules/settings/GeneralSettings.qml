import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// General: which panels exist and how they behave.
ColumnLayout {
    spacing: 22

    SettingsGroup {
        title: "Bar and dock"
        SettingRow {
            icon: ""; title: "Auto-hide the top bar"; hint: "Off keeps it visible and reserves its space"
            Switch { checked: Prefs.topAutoHide; onToggled: v => Prefs.set("topAutoHide", v) }
        }
        SettingRow {
            icon: ""; title: "Auto-hide the left dock"; hint: "Off keeps it visible and reserves its space"
            Switch { checked: Prefs.leftAutoHide; onToggled: v => Prefs.set("leftAutoHide", v) }
        }
    }

    SettingsGroup {
        title: "Screen"
        SettingRow {
            icon: ""; title: "Screen frame"; hint: "A border around the screen that the bar, dock and menus grow out of. Keep niri's gaps at least " + Config.frameSize + " px."
            Switch { checked: Prefs.frame; onToggled: v => Prefs.set("frame", v) }
        }
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
