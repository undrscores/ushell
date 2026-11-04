import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

// Now-playing card: album art, track info, cava spectrum, progress, controls.
Item {
    id: root
    visible: Media.available
    implicitHeight: visible ? col.implicitHeight : 0

    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec))
        return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0")
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 104; Layout.preferredHeight: 104
                radius: Theme.radius
                color: Theme.tint
                clip: true
                Icon { anchors.centerIn: parent; text: ""; size: 30; color: Theme.fgDim; visible: art.status !== Image.Ready }
                Image {
                    id: art
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    Layout.fillWidth: true
                    text: Media.title || "Nothing playing"
                    color: Theme.fg
                    elide: Text.ElideRight
                    maximumLineCount: 2; wrapMode: Text.Wrap
                    font { family: Theme.font; pixelSize: Theme.fontSize + 3; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: Media.artist
                    color: Theme.fgDim
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
                Text {
                    Layout.fillWidth: true
                    text: Media.identity
                    color: Theme.accent
                    opacity: 0.8
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
            }
        }

        Visualizer { Layout.fillWidth: true; Layout.preferredHeight: 44 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Slider {
                Layout.fillWidth: true
                value: Media.length > 0 ? Media.position / Media.length : 0
                onMoved: v => Media.seek(v)
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: root.fmt(Media.position); color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
                Item { Layout.fillWidth: true }
                Text { text: root.fmt(Media.length); color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            IconButton { size: 38; icon: ""; onClicked: Media.prev() }
            IconButton { size: 46; icon: Media.playing ? "" : ""; active: true; tone: Theme.accent; onClicked: Media.toggle() }
            IconButton { size: 38; icon: ""; onClicked: Media.next() }
        }
    }
}
