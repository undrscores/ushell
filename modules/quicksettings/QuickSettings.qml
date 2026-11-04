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
                    value: Audio.volume
                    tone: Audio.muted ? Theme.fgDim : Theme.accent
                    onMoved: v => Audio.setVolume(v)
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

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }

            // Output devices
            Column {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: Audio.sinks
                    delegate: Rectangle {
                        id: dev
                        required property var modelData
                        readonly property bool current: Audio.sink && Audio.sink.id === modelData.id
                        width: parent.width; height: 36
                        radius: Theme.radiusSmall + 2
                        color: current ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Text {
                            anchors { left: parent.left; leftMargin: 12; right: tick.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: Audio.nodeName(dev.modelData)
                            color: dev.current ? Theme.fg : Theme.fgDim
                            font { family: Theme.font; pixelSize: Theme.fontSize }
                        }
                        Icon { id: tick; visible: dev.current; text: ""; size: 12; color: Theme.accent
                               anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: Audio.setSink(dev.modelData) }
                    }
                }
            }
        }
    }
}
