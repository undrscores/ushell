import QtQuick
import "../config"

// One line of text that scrolls sideways when it is wider than the space it has, and rests otherwise.
Item {
    id: root
    property string text: ""
    property color color: Theme.fg
    property int pixelSize: Theme.fontSize
    property bool bold: false
    property bool running: true
    readonly property real overflow: Math.max(0, label.implicitWidth - width)

    implicitHeight: label.implicitHeight
    clip: true

    Text {
        id: label
        text: root.text
        color: root.color
        font { family: Theme.font; pixelSize: root.pixelSize; bold: root.bold }
        x: 0
    }
    SequentialAnimation {
        running: root.running && root.overflow > 0 && root.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running) label.x = 0
        PauseAnimation { duration: 1800 }
        NumberAnimation { target: label; property: "x"; to: -root.overflow; duration: Math.max(1200, root.overflow * 28); easing.type: Easing.InOutSine }
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: label; property: "x"; to: 0; duration: 600; easing.type: Easing.InOutSine }
    }
    onTextChanged: label.x = 0
}
