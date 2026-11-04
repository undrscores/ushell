import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../config"
import "../services"

// Now-playing card: spinning vinyl art, blurred backdrop, spectrum, progress, controls.
Item {
    id: root
    visible: Media.available
    implicitHeight: visible ? col.implicitHeight + 32 : 0

    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec))
        return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0")
    }

    // Blurred album-art backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.tint
        clip: true
        Image { id: bgSrc; anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
        MultiEffect {
            anchors.fill: parent
            source: bgSrc
            blurEnabled: true; blur: 1.0; blurMax: 48
            brightness: -0.15; saturation: 0.3
            opacity: bgSrc.status === Image.Ready ? 0.55 : 0
            Behavior on opacity { NumberAnimation { duration: 500 } }
        }
        Rectangle { anchors.fill: parent; color: Theme.glass; opacity: 0.35 }
    }

    ColumnLayout {
        id: col
        x: 16; y: 16
        width: parent.width - 32
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // Vinyl-style art: spins while playing, pulses with the bass
            Item {
                Layout.preferredWidth: 100; Layout.preferredHeight: 100
                Rectangle {  // bass glow
                    anchors.centerIn: parent
                    width: 100 + 26 * Cava.bass; height: width; radius: width / 2
                    color: Theme.accent
                    opacity: Media.playing ? 0.12 + 0.35 * Cava.bass : 0
                    Behavior on width { NumberAnimation { duration: 80 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Item {
                    id: disc
                    anchors.centerIn: parent
                    width: 96; height: 96
                    scale: 1 + 0.07 * Cava.bass
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    NumberAnimation on rotation {
                        from: 0; to: 360; duration: 14000
                        loops: Animation.Infinite
                        running: true
                        paused: !Media.playing
                    }
                    Rectangle {
                        id: mask
                        anchors.fill: parent; radius: width / 2; visible: false
                        layer.enabled: true
                    }
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.surface }
                    Icon { anchors.centerIn: parent; text: ""; size: 28; color: Theme.fgDim; visible: art.status !== Image.Ready }
                    Image { id: art; anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
                    MultiEffect {
                        anchors.fill: parent
                        source: art
                        maskEnabled: true; maskSource: mask
                        opacity: art.status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                    }
                    Rectangle {  // spindle hole
                        anchors.centerIn: parent; width: 14; height: 14; radius: 7
                        color: Theme.glass; border { color: Theme.line; width: 1 }
                    }
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border { color: Theme.line; width: 1 } }
                }
            }

            ColumnLayout {
                id: info
                Layout.fillWidth: true
                spacing: 3
                Text {
                    id: titleText
                    Layout.fillWidth: true
                    text: Media.title || "Nothing playing"
                    color: Theme.fg
                    elide: Text.ElideRight
                    maximumLineCount: 2; wrapMode: Text.Wrap
                    font { family: Theme.font; pixelSize: Theme.fontSize + 3; bold: true }
                    onTextChanged: swap.restart()
                }
                Text {
                    id: artistText
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
                // track-change flourish
                ParallelAnimation {
                    id: swap
                    NumberAnimation { target: info; property: "opacity"; from: 0; to: 1; duration: 380; easing.type: Theme.easing }
                    NumberAnimation { target: info; property: "x"; from: 14; to: 0; duration: 380; easing.type: Easing.OutBack }
                }
            }
        }

        Visualizer { Layout.fillWidth: true; Layout.preferredHeight: 56 }

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
            spacing: 12
            IconButton { size: 38; icon: ""; onClicked: Media.prev() }
            IconButton { size: 48; icon: Media.playing ? "" : ""; active: true; tone: Theme.accent; onClicked: Media.toggle() }
            IconButton { size: 38; icon: ""; onClicked: Media.next() }
        }
    }
}
