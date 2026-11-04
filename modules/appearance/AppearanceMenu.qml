import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"
import "../../config/palette.js" as Palette

// Appearance dropdown: dark / light, accent colour (or the wallpaper's), and the wallpaper itself.
// Open it from Settings, the launcher ("Appearance"), or `qs ipc call shell toggle appearance`.
Overlay {
    id: root
    name: "appearance"
    onOpenChanged: if (open) Wallpapers.refresh()

    // the wallpaper's colour, when the theme is following it (used by the previews)
    readonly property var wall: Wallpapers.useColors ? ({ hue: Wallpapers.hue, sat: Wallpapers.sat }) : null

    DropCard {
        id: card
        open: root.open
        contentWidth: 372
        contentHeight: col.implicitHeight

        component Section: Text {
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2; letterSpacing: 0.6 }
        }

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 12

            // ── dark / light ────────────────────────────────────────────────
            Section { text: "Theme" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: ["dark", "light"]
                    delegate: Rectangle {
                        id: mc
                        required property string modelData
                        // how this mode would look with the current accent / wallpaper
                        readonly property var p: Palette.make(modelData, Prefs.accent, root.wall)
                        readonly property bool chosen: Prefs.themeMode === modelData
                        Layout.fillWidth: true
                        implicitHeight: 88
                        radius: Theme.radius
                        color: p.bg
                        border { width: chosen ? 2 : 1; color: chosen ? Theme.accent : Theme.line }
                        scale: mma.pressed ? 0.96 : (mma.containsMouse ? 1.03 : 1)
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
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
                            Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 3 } }
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

            // ── accent ──────────────────────────────────────────────────────
            Section { text: "Accent" }
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
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
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
                    color: Wallpapers.colorsOk ? Palette.make(Theme.mode, "mauve", { hue: Wallpapers.hue, sat: Wallpapers.sat }).accent : Theme.surfaceHi
                    Behavior on color { ColorAnimation { duration: Theme.animFade } }
                    border { width: Prefs.wallpaperColors ? 2 : 1; color: Prefs.wallpaperColors ? Theme.fg : Theme.line }
                    opacity: usable ? 1 : 0.35
                    scale: wMa.pressed ? 0.85 : (wMa.containsMouse && usable ? 1.18 : (Prefs.wallpaperColors ? 1.08 : 1))
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
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
                    : !Prefs.wallpaperColors ? "The last swatch colours the whole theme from the wallpaper"
                    : Wallpapers.colorsOk ? "Colours follow the wallpaper"
                    : "Reading the wallpaper… (a grey picture has no colour to use)"
            }

            // ── wallpaper ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Section { Layout.fillWidth: true; text: "Wallpaper" }
                Pill { label: "Random"; visible: Wallpapers.files.length > 1; onClicked: Wallpapers.random() }
                Pill { label: "Browse"; onClicked: Shell.open("wallpapers") }
                Pill { label: "Off"; visible: Prefs.wallpaper !== ""; onClicked: Wallpapers.off() }
            }
            ListView {
                id: strip
                Layout.fillWidth: true
                implicitHeight: 60
                visible: Wallpapers.files.length > 0
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Wallpapers.files
                // wheel over the strip scrolls it sideways
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: e => strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - (e.angleDelta.y + e.angleDelta.x)))
                }
                delegate: Rectangle {
                    id: th
                    required property string modelData
                    readonly property bool chosen: modelData === Wallpapers.current
                    width: 96; height: 60
                    radius: Theme.radiusSmall + 2
                    color: Theme.tint
                    clip: true
                    border { width: chosen ? 2 : 0; color: Theme.accent }
                    scale: tma.containsMouse ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    Image {
                        anchors { fill: parent; margins: th.chosen ? 2 : 0 }
                        source: Wallpapers.url(th.modelData)
                        sourceSize: Qt.size(192, 120)
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
            Text {
                Layout.fillWidth: true
                visible: Wallpapers.scanned && Wallpapers.files.length === 0
                wrapMode: Text.Wrap
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                text: "No pictures in " + Wallpapers.dir.replace(Wallpapers.home, "~") + ". Put some there, or set \"wallpaperDir\" in config.json."
            }
        }
    }
}
