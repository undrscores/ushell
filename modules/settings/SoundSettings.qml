import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Sound: volume and microphone, which device is used, and the volume of each running application.
ColumnLayout {
    spacing: 22

    SettingsGroup {
        title: "Volume"
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            IconButton { icon: Audio.icon(); size: 34; tone: Audio.muted ? Theme.danger : Theme.fg; onClicked: Audio.toggleMute() }
            Slider {
                Layout.fillWidth: true
                value: Audio.volume / Config.maxVolume
                tone: Audio.muted ? Theme.fgDim : Theme.accent
                onMoved: v => Audio.setVolume(v * Config.maxVolume)
            }
            Text {
                Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
                text: Math.round(Audio.volume * 100); color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            IconButton { icon: Audio.micMuted ? "" : ""; size: 34; tone: Audio.micMuted ? Theme.danger : Theme.fg; onClicked: Audio.toggleMic() }
            Slider {
                Layout.fillWidth: true
                value: Audio.micVolume
                tone: Audio.micMuted ? Theme.fgDim : Theme.accent
                onMoved: v => Audio.setMicVolume(v)
            }
            Text {
                Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
                text: Math.round(Audio.micVolume * 100); color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }
    }

    SettingsGroup {
        title: "Output"
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

    SettingsGroup {
        title: "Input"
        visible: Audio.sources.length > 1
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

    SettingsGroup {
        title: "Applications"
        Text {
            visible: Audio.streams.length === 0
            Layout.fillWidth: true
            text: "Nothing is playing or recording right now."
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
        }
        Repeater {
            model: Audio.streams
            delegate: AppVolumeRow {
                required property var modelData
                Layout.fillWidth: true
                node: modelData
            }
        }
    }
}
