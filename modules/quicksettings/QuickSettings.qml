import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Overlay {
    id: root
    name: "quicksettings"
    onOpenChanged: if (open) Brightness.ensure()

    DropCard {
        id: card
        open: root.open
        contentWidth: 320
        contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 14

            // Volume
            RowLayout {
                spacing: 12
                IconButton {
                    icon: Audio.icon(); size: 34
                    tone: Audio.muted ? Theme.danger : Theme.fg
                    onClicked: Audio.toggleMute()
                }
                Slider {
                    Layout.fillWidth: true
                    value: Audio.volume / Config.maxVolume
                    tone: Audio.muted ? Theme.fgDim : Theme.accent
                    onMoved: v => Audio.setVolume(v * Config.maxVolume)
                }
                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Audio.volume * 100)
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
            }

            // Microphone
            RowLayout {
                spacing: 12
                IconButton {
                    icon: Audio.micMuted ? "" : ""; size: 34
                    tone: Audio.micMuted ? Theme.danger : Theme.fg
                    onClicked: Audio.toggleMic()
                }
                Slider {
                    Layout.fillWidth: true
                    value: Audio.micVolume
                    tone: Audio.micMuted ? Theme.fgDim : Theme.accent
                    onMoved: v => Audio.setMicVolume(v)
                }
                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Audio.micVolume * 100)
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
            }

            // Brightness (one slider per DDC-capable monitor)
            Repeater {
                model: Brightness.displays
                delegate: RowLayout {
                    id: br
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Icon { text: "\uf185"; size: 17; color: Theme.fg; Layout.preferredWidth: 34; horizontalAlignment: Text.AlignHCenter }
                    Slider {
                        Layout.fillWidth: true
                        value: br.modelData.value / 100
                        tone: Theme.accent2
                        onMoved: v => Brightness.set(br.modelData.bus, v * 100)
                    }
                    Text {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(br.modelData.value)
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize }
                    }
                }
            }
            Text {
                visible: Brightness.detecting || Brightness.missing
                text: Brightness.detecting ? "Reading monitor brightness…" : "No DDC monitor found for brightness"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            }

            // Do Not Disturb
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                IconButton {
                    icon: Notifications.silent ? "\uf1f6" : "\uf0f3"; size: 34
                    active: Notifications.silent
                    tone: Notifications.silent ? Theme.danger : Theme.fg
                    onClicked: Notifications.toggleDnd()
                }
                Text {
                    Layout.fillWidth: true
                    text: Notifications.scheduled && !Notifications.dnd ? "Do not disturb · quiet hours" : "Do not disturb"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
                Switch { checked: Notifications.dnd; onToggled: v => Notifications.setDnd(v) }
            }

            // Keep awake (no idle lock / screen-off)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                IconButton {
                    icon: "\uf0f4"; size: 34
                    active: Idle.keepAwake
                    tone: Idle.keepAwake ? Theme.accent : Theme.fg
                    onClicked: Idle.toggle()
                }
                Text {
                    Layout.fillWidth: true
                    text: "Keep awake"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
                Switch { checked: Idle.keepAwake; onToggled: v => Idle.keepAwake = v }
            }

            // Focus mode (silent notifications, no capsule or radial menu)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                IconButton {
                    icon: "\uf06e"; size: 34
                    active: Prefs.focusMode
                    tone: Prefs.focusMode ? Theme.accent : Theme.fg
                    onClicked: Prefs.set("focusMode", !Prefs.focusMode)
                }
                Text {
                    Layout.fillWidth: true
                    text: "Focus mode"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
                Switch { checked: Prefs.focusMode; onToggled: v => Prefs.set("focusMode", v) }
            }

            // Night light
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                opacity: NightLight.available ? 1 : 0.55
                IconButton {
                    icon: "\uf186"; size: 34
                    active: NightLight.on
                    tone: NightLight.on ? Theme.accent : Theme.fg
                    onClicked: if (NightLight.available) Prefs.set("nightLight", !Prefs.nightLight)
                }
                Text {
                    Layout.fillWidth: true
                    text: !NightLight.available ? "Night light · not installed" : (NightLight.failed ? "Night light · could not start" : "Night light")
                    color: Theme.fg
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
                Switch { enabled: NightLight.available; checked: Prefs.nightLight; onToggled: v => Prefs.set("nightLight", v) }
            }

            // Battery (laptops)
            RowLayout {
                visible: Power.hasBattery
                Layout.fillWidth: true
                spacing: 12
                Icon { text: Power.glyph; size: 17; color: Power.low ? Theme.danger : (Power.charging ? Theme.accent : Theme.fg)
                       Layout.preferredWidth: 34; horizontalAlignment: Text.AlignHCenter }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3; color: Theme.hover
                        Rectangle {
                            width: Math.max(parent.height, parent.width * Power.pct / 100); height: parent.height; radius: 3
                            color: Power.low ? Theme.danger : (Power.charging ? Theme.accent2 : Theme.accent)
                            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Power.timeText
                        visible: text !== ""
                        elide: Text.ElideRight
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                    }
                }
                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: Power.level + "%"
                    color: Power.low ? Theme.danger : Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
            }

            // Power profile
            RowLayout {
                visible: Power.profileAvailable
                Layout.fillWidth: true
                spacing: 12
                Icon { text: Power.current.glyph; size: 17; color: Theme.fg; Layout.preferredWidth: 34; horizontalAlignment: Text.AlignHCenter }
                Row {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: Power.offered
                        delegate: Pill { required property var modelData; label: modelData.title; active: Power.current.id === modelData.id
                                         onClicked: Power.setProfile(modelData.id) }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }

            // Output devices
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                SectionLabel { text: "Output" }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: Audio.sinks
                        delegate: DeviceRow {
                            required property var modelData
                            width: parent.width
                            label: Audio.nodeName(modelData)
                            current: !!Audio.sink && Audio.sink.id === modelData.id
                            onClicked: Audio.setSink(modelData)
                        }
                    }
                }
            }

            // Input devices: only worth a list when there is something to choose between
            ColumnLayout {
                Layout.fillWidth: true
                visible: Audio.sources.length > 1
                spacing: 4
                SectionLabel { text: "Input" }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: Audio.sources
                        delegate: DeviceRow {
                            required property var modelData
                            width: parent.width
                            label: Audio.nodeName(modelData)
                            current: !!Audio.source && Audio.source.id === modelData.id
                            onClicked: Audio.setSource(modelData)
                        }
                    }
                }
            }

            // Per-application volume (the first few; a browser can have many streams)
            ColumnLayout {
                Layout.fillWidth: true
                visible: Audio.streams.length > 0
                spacing: 8
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
                SectionLabel { text: "Applications" }
                Repeater {
                    model: Audio.streams.slice(0, 6)
                    delegate: AppVolumeRow {
                        required property var modelData
                        Layout.fillWidth: true
                        node: modelData
                    }
                }
                Text {
                    visible: Audio.streams.length > 6
                    text: "+" + (Audio.streams.length - 6) + " more"
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
            }
        }
    }
}
