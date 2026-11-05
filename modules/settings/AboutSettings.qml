import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// About: where the shell keeps its files, and a reload button.
ColumnLayout {
    spacing: 22

    component Path_: Text {
        color: Theme.fgDim
        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignRight
        width: 300
    }

    SettingsGroup {
        title: "Files"
        SettingRow {
            icon: ""; title: "Your settings file"; hint: "Optional. Copy config.example.json there to change app pins, the lock command and more."
            Path_ { text: Config.path.replace(StateDir.home, "~") }
        }
        SettingRow {
            icon: ""; title: "Saved choices"; hint: "What you pick in this window is stored here"
            Path_ { text: StateDir.dir.replace(StateDir.home, "~") }
        }
        SettingRow {
            icon: ""; title: "Shell folder"; hint: "The code this shell runs from"
            Path_ { text: Quickshell.shellPath("").replace(StateDir.home, "~") }
        }
    }

    SettingsGroup {
        title: "Shell"
        SettingRow {
            icon: ""; title: "Reload the shell"; hint: "It also reloads by itself whenever a file changes"
            Pill { label: "Reload"; onClicked: Quickshell.reload(false) }
        }
    }
}
