import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"
import "../../config/palette.js" as Palette

// Settings dropdown (gear in the top pill, or `qs ipc call shell toggle settings`).
Overlay {
    id: root
    name: "settings"

    DropCard {
        id: card
        open: root.open
        contentWidth: 340
        contentHeight: col.implicitHeight

        component Row_: RowLayout {
            id: r
            property string title
            property string hint
            default property alias control: slot.data
            Layout.fillWidth: true
            spacing: 12
            Column {
                Layout.fillWidth: true
                spacing: 2
                Text { text: r.title; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize } }
                Text { visible: r.hint !== ""; text: r.hint; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 3 } }
            }
            Item { id: slot; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
        }

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 14

            Text { text: "Panels"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2; letterSpacing: 0.6 } }
            Row_ {
                title: "Auto-hide top pill"; hint: "Off keeps it visible and reserves space"
                Switch { checked: Prefs.topAutoHide; onToggled: v => Prefs.set("topAutoHide", v) }
            }
            Row_ {
                title: "Auto-hide left dock"; hint: "Off keeps it visible and reserves space"
                Switch { checked: Prefs.leftAutoHide; onToggled: v => Prefs.set("leftAutoHide", v) }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
            Text { text: "Appearance"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2; letterSpacing: 0.6 } }
            Row_ {
                title: "Light theme"; hint: "Off is the dark theme"
                Switch { checked: Prefs.themeMode === "light"; onToggled: v => Prefs.set("themeMode", v ? "light" : "dark") }
            }
            Row {
                spacing: 8
                Repeater {
                    model: Palette.names
                    delegate: Rectangle {
                        id: sw
                        required property string modelData
                        readonly property bool chosen: Palette.make(Theme.mode, Prefs.accent).accentName === modelData
                        width: 22; height: 22; radius: 11
                        color: Palette.make(Theme.mode, modelData).accent
                        opacity: Wallpapers.useColors ? 0.35 : 1          // ignored while the wallpaper sets the accent
                        border { width: chosen && !Wallpapers.useColors ? 2 : 0; color: Theme.fg }
                        scale: swMa.pressed ? 0.88 : (swMa.containsMouse ? 1.18 : 1)
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                        MouseArea { id: swMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("accent", sw.modelData) }
                    }
                }
            }

            Row_ {
                title: "Colors from wallpaper"
                hint: Prefs.wallpaperColors && Prefs.wallpaper !== "" && !Wallpapers.colorsOk ? "Reading it… or this picture has no colour" : "Accent, background and text follow the wallpaper"
                Switch { checked: Prefs.wallpaperColors; onToggled: v => Prefs.set("wallpaperColors", v) }
            }
            Row_ {
                title: "Wallpaper"
                hint: Prefs.wallpaper === "" ? "None chosen: another program may be drawing it" : Wallpapers.nameOf(Prefs.wallpaper)
                Rectangle {
                    implicitWidth: chooseText.implicitWidth + 24; implicitHeight: 28
                    radius: height / 2
                    color: chooseMa.containsMouse ? Theme.hover : Theme.tint
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text { id: chooseText; anchors.centerIn: parent; text: "Choose…"; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } }
                    MouseArea { id: chooseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("wallpapers") }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
            Text { text: "Weather"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2; letterSpacing: 0.6 } }
            Row_ {
                title: "Metric units"; hint: "°C and km/h instead of °F and mph"
                Switch { checked: Prefs.weatherMetric; onToggled: v => Prefs.set("weatherMetric", v) }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.radius
                color: Theme.tint
                border { width: 1; color: city.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }
                TextInput {
                    id: city
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                    clip: true
                    text: Prefs.weatherCity
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    onAccepted: { Prefs.set("weatherCity", text.trim()); focus = false }
                    onActiveFocusChanged: if (!activeFocus) Prefs.set("weatherCity", text.trim())
                    Keys.onEscapePressed: Shell.close()
                    Text { visible: !city.text; text: "City (empty = detect by IP)"; color: Theme.fgDim; font: city.font; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
