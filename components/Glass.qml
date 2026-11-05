import QtQuick
import "../config"

// The one panel surface used everywhere: translucent, hairline border.
Rectangle {
    radius: Theme.radius + 4
    color: Theme.glass
    border { color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12); width: 1 }
    clip: true
    // soft top sheen
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
        height: 40
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    // soft shade toward the bottom edge, so the panel reads as a raised surface
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }
        height: Math.min(80, parent.height / 2)
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.14) }
        }
    }
    // swallow clicks so the backdrop doesn't close the panel
    MouseArea { anchors.fill: parent }
}
