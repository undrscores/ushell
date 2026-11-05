import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

// One application's playback volume: mute button, name and slider. `node` is its PipeWire stream.
RowLayout {
    id: root
    property var node
    readonly property real volume: node && node.audio ? node.audio.volume : 0
    readonly property bool muted: node && node.audio ? node.audio.muted : false
    spacing: 10

    IconButton {
        icon: root.muted || root.volume <= 0 ? "" : (root.volume < 0.5 ? "" : "")
        size: 30
        tone: root.muted ? Theme.danger : Theme.fg
        onClicked: Audio.toggleNodeMute(root.node)
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Audio.appName(root.node)
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
        }
        Slider {
            Layout.fillWidth: true
            value: root.volume / Config.maxVolume
            tone: root.muted ? Theme.fgDim : Theme.accent
            onMoved: v => Audio.setNodeVolume(root.node, v * Config.maxVolume)
        }
    }
    Text {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.volume * 100)
        color: Theme.fgDim
        font { family: Theme.font; pixelSize: Theme.fontSize }
    }
}
