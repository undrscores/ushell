import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"
import "../../config/palette.js" as Palette

// Appearance: dark / light, accent colour (or the wallpaper's), and the wallpaper itself.
ColumnLayout {
    id: page
    spacing: 22
    Component.onCompleted: Wallpapers.refresh()

    // the wallpaper's colour, when the theme is following it (used by the previews)
    readonly property var wall: Wallpapers.useColors ? ({ hue: Wallpapers.hue, sat: Wallpapers.sat, hue2: Wallpapers.hue2 >= 0 ? Wallpapers.hue2 : undefined, sat2: Wallpapers.sat2 }) : null

    SettingsGroup {
        title: "Theme"
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: ["dark", "light"]
                delegate: Rectangle {
                    id: mc
                    required property string modelData
                    // how this mode would look with the current accent / wallpaper
                    readonly property var p: Palette.make(modelData, Prefs.accent, page.wall)
                    readonly property bool chosen: Prefs.themeMode === modelData
                    Layout.fillWidth: true
                    implicitHeight: 88
                    radius: Theme.radius
                    color: p.bg
                    border { width: chosen ? 2 : 1; color: chosen ? Theme.accent : Theme.line }
                    scale: mma.pressed ? 0.96 : (mma.containsMouse ? 1.03 : 1)
                    Behavior on scale { Pop {} }
                    Behavior on color { ColorAnimation { duration: Theme.animFade } }

                    Rectangle {          // a miniature window
                        x: 10; y: 10
                        width: parent.width - 20; height: 36
                        radius: 8
                        color: mc.p.surface
                        Rectangle { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8; color: mc.p.accent }
                        Rectangle { x: 34; y: 11; width: 50; height: 5; radius: 2.5; color: mc.p.fg }
                        Rectangle { x: 34; y: 21; width: 32; height: 4; radius: 2; color: mc.p.fgDim }
                    }
                    Text {
                        x: 12; anchors { bottom: parent.bottom; bottomMargin: 9 }
                        text: mc.modelData === "dark" ? "Dark" : "Light"
                        color: mc.p.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                    }
                    Icon {
                        anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 9 }
                        text: ""; size: 12; color: mc.p.accent
                        opacity: mc.chosen ? 1 : 0
                        scale: mc.chosen ? 1 : 0.4
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                        Behavior on scale { Pop { duration: 360; overshoot: 3 } }
                    }
                    MouseArea {
                        id: mma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Prefs.set("themeMode", mc.modelData)
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: "Accent colour"
        Row {
            spacing: 8
            Repeater {
                model: Palette.names
                delegate: Rectangle {
                    id: sw
                    required property string modelData
                    readonly property bool chosen: !Prefs.wallpaperColors && Palette.make(Theme.mode, Prefs.accent).accentName === modelData
                    width: 24; height: 24; radius: 12
                    color: Palette.make(Theme.mode, modelData).accent
                    border { width: chosen ? 2 : 0; color: Theme.fg }
                    opacity: Wallpapers.useColors ? 0.45 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    scale: swMa.pressed ? 0.85 : (swMa.containsMouse ? 1.18 : (chosen ? 1.08 : 1))
                    Behavior on scale { Pop {} }
                    MouseArea {
                        id: swMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Prefs.set("accent", sw.modelData); Prefs.set("wallpaperColors", false) }
                    }
                }
            }
            Rectangle {          // "from the wallpaper": colours the whole theme from the picture
                id: wsw
                readonly property bool usable: Prefs.wallpaper !== ""
                width: 24; height: 24; radius: 12
                color: Wallpapers.colorsOk ? Palette.make(Theme.mode, "mauve", { hue: Wallpapers.hue, sat: Wallpapers.sat, hue2: Wallpapers.hue2 >= 0 ? Wallpapers.hue2 : undefined, sat2: Wallpapers.sat2 }).accent : Theme.surfaceHi
                Behavior on color { ColorAnimation { duration: Theme.animFade } }
                border { width: Prefs.wallpaperColors ? 2 : 1; color: Prefs.wallpaperColors ? Theme.fg : Theme.line }
                opacity: usable ? 1 : 0.35
                scale: wMa.pressed ? 0.85 : (wMa.containsMouse && usable ? 1.18 : (Prefs.wallpaperColors ? 1.08 : 1))
                Behavior on scale { Pop {} }
                Icon { anchors.centerIn: parent; text: ""; size: 11; color: Wallpapers.colorsOk ? Theme.accentFg : Theme.fgDim }
                MouseArea {
                    id: wMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: wsw.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Prefs.set("wallpaperColors", !Prefs.wallpaperColors)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
            text: Prefs.wallpaper === "" ? "Choose a wallpaper below to colour the theme from it"
                : Wallpapers.failed === Prefs.wallpaper ? "Couldn't load this picture; it may have been moved or deleted. Pick another one below."
                : !Prefs.wallpaperColors ? "The last swatch colours the whole theme from the wallpaper"
                : Wallpapers.colorsOk ? "Colours follow the wallpaper"
                : !Wallpapers.colorsRead ? "Reading the wallpaper…"
                : Wallpapers.colorError !== "" ? "Couldn't read this picture's colours: " + Wallpapers.colorError
                : "This picture is grey, so it has no colour to use"
        }
    }

    SettingsGroup {
        title: "Wallpaper"
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Pill { label: "Random"; visible: Wallpapers.files.length > 1; onClicked: Wallpapers.random() }
            Pill { label: "Browse"; onClicked: Shell.open("wallpapers") }
            Pill { label: "Off"; visible: Prefs.wallpaper !== ""; onClicked: Wallpapers.off() }
        }
        Flow {
            Layout.fillWidth: true
            visible: Wallpapers.files.length > 0
            spacing: 10
            Repeater {
                model: Wallpapers.files
                delegate: Rectangle {
                    id: th
                    required property string modelData
                    readonly property bool chosen: modelData === Wallpapers.current
                    width: 148; height: 90
                    radius: Theme.radiusSmall + 2
                    color: Theme.bg
                    clip: true
                    border { width: chosen ? 2 : 1; color: chosen ? Theme.accent : Theme.line }
                    scale: tma.containsMouse ? 1.04 : 1
                    Behavior on scale { Spring { preset: "snap"; epsilon: 0.002 } }
                    Image {
                        anchors { fill: parent; margins: th.chosen ? 2 : 1 }
                        source: Wallpapers.url(th.modelData)
                        sourceSize: Qt.size(296, 180)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MouseArea {
                        id: tma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.set(th.modelData)
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: Wallpapers.scanned && Wallpapers.files.length === 0
            wrapMode: Text.Wrap
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            text: "No pictures in " + Wallpapers.dir.replace(Wallpapers.home, "~") + ". Put some there, or set \"wallpaperDir\" in config.json."
        }
    }

    SettingsGroup {
        title: "Day and night"
        SettingRow {
            icon: "\uf186"; title: "Switch theme by the time of day"
            hint: "Light from the first time, dark from the second. A change you make by hand stands until the next switch."
            Switch { checked: Prefs.themeSchedule; onToggled: v => Prefs.set("themeSchedule", v) }
        }
        RowLayout {
            visible: Prefs.themeSchedule
            Layout.fillWidth: true
            Layout.leftMargin: 40
            spacing: 10
            Text { text: "Light from"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
            TimeField { value: Prefs.themeLightFrom; onEdited: v => Prefs.set("themeLightFrom", v) }
            Text { text: "dark from"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
            TimeField { value: Prefs.themeDarkFrom; onEdited: v => Prefs.set("themeDarkFrom", v) }
            Item { Layout.fillWidth: true }
        }
        SettingRow {
            visible: Prefs.themeSchedule
            icon: "\uf2c9"; title: "Night light in the dark part"
            hint: NightLight.available ? "Turns the warm tint on and off with the theme" : "Install wlsunset to use this"
            Switch { enabled: NightLight.available; checked: Prefs.scheduleNightLight; onToggled: v => Prefs.set("scheduleNightLight", v) }
        }
    }

    SettingsGroup {
        visible: Quickshell.screens.length > 1
        title: "Screens"
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            text: "Each screen can have its own wallpaper; the theme's colours still follow the main one. In the wallpaper picker, Shift+Enter sets it for the screen you are on."
        }
        Repeater {
            model: Quickshell.screens
            delegate: SettingRow {
                id: scr
                required property var modelData
                readonly property string own: Prefs.monitorWallpapers[modelData.name] ?? ""
                icon: "\uf108"; title: modelData.name
                hint: own !== "" ? Wallpapers.nameOf(own) : "Main wallpaper"
                Row {
                    spacing: 4
                    Pill { label: "Use current"; enabled: Prefs.wallpaper !== ""; onClicked: Wallpapers.setFor(scr.modelData.name, Prefs.wallpaper) }
                    Pill { visible: scr.own !== ""; label: "Reset"; onClicked: Wallpapers.resetFor(scr.modelData.name) }
                }
            }
        }
    }
}
