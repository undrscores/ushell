import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Control tab: the switches and sliders you reach for most, as tiles.
// Wi-Fi and Bluetooth tiles: the icon switches it, the text opens its menu.
Item {
    id: page
    implicitHeight: col.implicitHeight
    Component.onCompleted: Brightness.ensure()

    // one toggle tile: the icon on top, the name and its state underneath.
    // `menu` set: the icon switches it, the rest of the tile opens that menu (a chevron says so).
    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        property string menu: ""
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredWidth: 1                 // two equal columns
        implicitHeight: 96
        radius: Theme.radius
        color: on ? Theme.accentSoft : (bodyMa.containsMouse && enabled ? Theme.hover : Theme.tint)
        border { width: 1; color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : "transparent" }
        opacity: enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        MouseArea {
            id: bodyMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: tile.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: { if (!tile.enabled) return; if (tile.menu !== "") Shell.toggle(tile.menu); else tile.toggled() }
        }
        Rectangle {
            id: dot
            x: 14; y: 14
            width: 36; height: 36; radius: 18
            color: tile.on ? Theme.accent : Theme.hover
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            scale: dotMa.pressed ? 0.9 : (dotMa.containsMouse ? 1.08 : 1)
            Behavior on scale { Bounce {} }
            Icon { anchors.centerIn: parent; text: tile.icon; size: 16; color: tile.on ? Theme.accentFg : Theme.fg }
            MouseArea {
                id: dotMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: tile.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (tile.enabled) tile.toggled()
            }
        }
        Icon {          // this tile has a menu behind it
            visible: tile.menu !== ""
            anchors { right: parent.right; rightMargin: 14; verticalCenter: dot.verticalCenter }
            text: "\uf054"; size: 11
            color: Theme.fgDim
        }
        Column {
            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 13 }
            spacing: 2
            Text {
                width: parent.width; elide: Text.ElideRight
                text: tile.title
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: tile.sub
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            }
        }
    }

    // a labelled slider row: an icon button, the slider, and the value
    component SliderRow: Rectangle {
        id: sr
        property string icon: ""
        property string title: ""
        property real value: 0                  // 0..1
        property color tone: Theme.accent
        property color iconTone: Theme.fg
        property string valueText: Math.round(value * 100)
        signal moved(real v)
        signal iconClicked()

        Layout.fillWidth: true
        implicitHeight: 76
        radius: Theme.radius
        color: Theme.tint

        Text {
            x: 16; y: 13
            text: sr.title
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
        }
        Text {
            anchors { right: parent.right; rightMargin: 16 }
            y: 13
            text: sr.valueText
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
        }
        RowLayout {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 20; bottomMargin: 12 }
            spacing: 8
            IconButton { icon: sr.icon; size: 30; tone: sr.iconTone; onClicked: sr.iconClicked() }
            Slider { Layout.fillWidth: true; value: sr.value; tone: sr.tone; onMoved: v => sr.moved(v) }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12; rowSpacing: 12

            Tile {
                enabled: Network.available
                icon: Network.glyph; title: "Wi-Fi"
                on: Network.available && Network.wifiOn
                sub: !Network.available ? "Unavailable" : (!Network.wifiOn ? "Off" : (Network.kind === "wifi" && Network.name !== "" ? Network.name : "Not connected"))
                menu: "network"
                onToggled: Network.setWifi(!Network.wifiOn)
            }
            Tile {
                enabled: Bt.available
                icon: Bt.glyph; title: "Bluetooth"
                on: Bt.on
                sub: !Bt.available ? "Unavailable" : (!Bt.on ? "Off" : (Bt.connectedCount > 0 ? Bt.connectedCount + " connected" : "On"))
                menu: "bluetooth"
                onToggled: Bt.setOn(!Bt.on)
            }
            Tile {
                icon: Notifications.silent ? "" : ""; title: "Do Not Disturb"
                on: Notifications.dnd
                sub: Notifications.dnd ? "On" : (Notifications.scheduled ? "Quiet hours" : "Off")
                onToggled: Notifications.toggleDnd()
            }
            Tile {
                icon: ""; title: "Focus"
                on: Prefs.focusMode
                sub: Prefs.focusMode ? "On" : "Off"
                onToggled: Prefs.set("focusMode", !Prefs.focusMode)
            }
            Tile {
                icon: ""; title: "Night light"
                on: NightLight.on
                enabled: NightLight.available
                sub: !NightLight.available ? "Not installed" : (NightLight.failed ? "Could not start" : (NightLight.on ? Prefs.nightTemp + " K" : "Off"))
                onToggled: Prefs.set("nightLight", !Prefs.nightLight)
            }
            Tile {
                icon: ""; title: "Keep awake"
                on: Idle.keepAwake
                sub: Idle.keepAwake ? "On" : "Off"
                onToggled: Idle.toggle()
            }
        }

        SliderRow {
            icon: Audio.icon(); title: "Sound"
            value: Audio.volume / Config.maxVolume
            tone: Audio.muted ? Theme.fgDim : Theme.accent
            iconTone: Audio.muted ? Theme.danger : Theme.fg
            valueText: Audio.muted ? "Muted" : Math.round(Audio.volume * 100)
            onMoved: v => Audio.setVolume(v * Config.maxVolume)
            onIconClicked: Audio.toggleMute()
        }

        Repeater {
            model: Brightness.displays
            delegate: SliderRow {
                required property var modelData
                icon: ""
                title: Brightness.displays.length > 1 ? "Display · " + modelData.name : "Display"
                value: modelData.value / 100
                tone: Theme.accent2
                valueText: Math.round(modelData.value)
                onMoved: v => Brightness.set(modelData.bus, v * 100)
            }
        }
    }
}
