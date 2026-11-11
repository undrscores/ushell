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
        title: "Backup"
        SettingRow {
            icon: "\uf0c7"; title: "Export or import your settings"
            hint: "Saves what you chose in Settings, plus config.json, as one file you can keep or copy to another machine. Importing skips anything invalid."
            Item {}
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Theme.radiusSmall + 2
                color: Theme.bg
                border { width: 1; color: pathInput.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : Theme.line }
                TextInput {
                    id: pathInput
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg; clip: true
                    selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                    font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    Text {
                        visible: pathInput.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: Backup.defaultPath.replace(StateDir.home, "~")
                        color: Theme.fgDim; font: pathInput.font
                    }
                }
            }
            Pill { label: "Export"; onClicked: Backup.exportTo(pathInput.text.trim().replace(/^~/, StateDir.home)) }
            Pill { label: "Import"; onClicked: Backup.importFrom(pathInput.text.trim().replace(/^~/, StateDir.home)) }
        }
        Text {
            visible: Backup.status !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Backup.status
            color: Backup.failed ? Theme.danger : Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
        }
    }

    SettingsGroup {
        title: "System check"
        SettingRow {
            icon: "\uf0ad"; title: Doctor.done ? (Doctor.missing.length === 0 ? "Everything ushell uses is installed" : Doctor.missing.length + " thing" + (Doctor.missing.length === 1 ? "" : "s") + " missing") : "Checking…"
            hint: "Fonts and helper programs the shell relies on. Features that need a missing one do nothing until you install it."
            Pill { label: "Check again"; onClicked: Doctor.run() }
        }
        Repeater {
            model: Doctor.missing
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "•  " + modelData.replace(/^warn\s+/, "")
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
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
