import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Weather: units and location for the widgets panel.
ColumnLayout {
    spacing: 22

    SettingsGroup {
        title: "Weather"
        SettingRow {
            icon: ""; title: "Metric units"; hint: "°C and km/h instead of °F and mph"
            Switch { checked: Prefs.weatherMetric; onToggled: v => Prefs.set("weatherMetric", v) }
        }
        SettingRow {
            icon: ""; title: "City"; hint: "Leave empty to find you by IP address"
            Rectangle {
                implicitWidth: 220; implicitHeight: 34
                radius: Theme.radiusSmall + 2
                color: Theme.bg
                border { width: 1; color: city.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : Theme.line }
                TextInput {
                    id: city
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                    clip: true
                    text: Prefs.weatherCity
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    onAccepted: focus = false                       // leaving the field is what saves it
                    onActiveFocusChanged: if (!activeFocus) Prefs.set("weatherCity", text.trim())
                    Keys.onEscapePressed: focus = false
                    Text { visible: !city.text; text: "e.g. Berlin"; color: Theme.fgDim; font: city.font; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
