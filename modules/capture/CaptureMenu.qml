import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Screenshot and screen recording panel (bar → camera, radial menu, `qs ipc call shell toggle capture`).
Overlay {
    id: root
    name: "capture"

    // one big button: glyph on top, name under it
    component Tile: Rectangle {
        id: tile
        property string icon
        property string title
        property bool off: false
        property bool hot: false
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 76
        radius: Theme.radius
        opacity: off ? 0.45 : 1
        color: hot ? Theme.accentSoft : (ma.containsMouse && !off ? Theme.hover : Theme.tint)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        scale: ma.pressed && !off ? 0.95 : 1
        Behavior on scale { Bounce {} }
        Column {
            anchors.centerIn: parent
            spacing: 8
            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: tile.icon; size: 20; color: tile.hot ? Theme.accent : Theme.fg }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.title
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: tile.off ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!tile.off) tile.clicked() }
    }

    DropCard {
        id: card
        open: root.open
        contentWidth: 340
        contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 14

            Text {
                text: "Capture"
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize + 2; bold: true }
            }

            // a recording is running: the only thing worth showing is how to stop it
            RowLayout {
                visible: Capture.recording
                Layout.fillWidth: true
                spacing: 12
                Rectangle { Layout.preferredWidth: 10; Layout.preferredHeight: 10; radius: 5; color: Theme.danger
                            SequentialAnimation on opacity { running: Capture.recording; loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                Text {
                    Layout.fillWidth: true
                    text: "Recording  " + Capture.fmt(Capture.elapsed)
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 1 }
                }
                Pill { label: "Stop"; active: true; onClicked: Capture.stopRecording() }
            }

            SectionLabel { visible: !Capture.recording; text: "Screenshot" }
            RowLayout {
                visible: !Capture.recording
                Layout.fillWidth: true
                spacing: 8
                Tile { icon: ""; title: "Region"; onClicked: Capture.screenshot("region") }
                Tile { icon: ""; title: "Screen"; onClicked: Capture.screenshot("screen") }
                Tile { icon: ""; title: "Window"; onClicked: Capture.screenshot("window") }
            }

            SectionLabel { visible: !Capture.recording; text: "Record" }
            RowLayout {
                visible: !Capture.recording
                Layout.fillWidth: true
                spacing: 8
                Tile { icon: ""; title: "Screen"; off: !Capture.canRecord; onClicked: Capture.record(false) }
                Tile { icon: ""; title: "Region"; off: !Capture.canRecord || !Capture.canPick; onClicked: Capture.record(true) }
            }
            Text {
                visible: !Capture.recording && !Capture.canRecord
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Install wf-recorder (and slurp, for a region) to record the screen."
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: "Delay"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } Layout.rightMargin: 4 }
                Repeater {
                    model: [0, 3, 5, 10]
                    delegate: Pill { required property int modelData; label: modelData === 0 ? "None" : modelData + "s"
                                     active: Prefs.captureDelay === modelData; onClicked: Prefs.set("captureDelay", modelData) }
                }
            }
            RowLayout {
                visible: Capture.canRecord
                Layout.fillWidth: true
                spacing: 12
                Text { Layout.fillWidth: true; text: "Record sound"; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize } }
                Switch { checked: Prefs.recordAudio; onToggled: v => Prefs.set("recordAudio", v) }
            }
            Text {
                Layout.fillWidth: true
                text: "Screenshots are copied to the clipboard and saved in " + Config.screenshotDir + ". Recordings go to " + Config.recordingDir + "."
                wrapMode: Text.Wrap
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            }
        }
    }
}
