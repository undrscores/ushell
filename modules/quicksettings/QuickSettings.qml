import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Overlay {
    id: root
    name: "quicksettings"

    Glass {
        id: card
        width: 340
        height: col.implicitHeight + 32
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.margin + Theme.barHeight + 6 + (root.open ? 0 : -10)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: root.open ? 420 : 200; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.4 } }
        Behavior on scale   { NumberAnimation { duration: root.open ? 420 : 200; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.6 } }
        Behavior on height  { NumberAnimation { duration: Theme.animFast;   easing.type: Theme.easing } }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
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
