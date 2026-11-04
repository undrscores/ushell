import QtQuick
import "../config"

// The one panel surface used everywhere: translucent, hairline border.
Rectangle {
    radius: Theme.radius + 4
    color: Theme.glass
    border { color: Theme.line; width: 1 }
    clip: true
    // soft top sheen
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
        height: 40
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.055) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    // swallow clicks so the backdrop doesn't close the panel
    MouseArea { anchors.fill: parent }
}
