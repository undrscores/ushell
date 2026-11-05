import QtQuick
import QtQuick.Effects
import "../config"

// The one panel surface used everywhere: translucent, hairline border.
Rectangle {
    radius: Theme.radiusLarge
    color: Theme.glass
    border { color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12); width: 1 }
    clip: true

    // A soft drop shadow under the panel (dropdown cards turn it on). It is drawn outside the panel, so the
    // window the panel sits in must be bigger than it; windows that hug their panel leave it off.
    property bool shadow: false
    // flat = no sheen, shade or outline: for panels that are part of the screen frame
    property bool flat: false
    layer.enabled: shadow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.5
        shadowBlur: 1.0
        shadowVerticalOffset: 10
        autoPaddingEnabled: true
    }
    // soft top sheen
    Rectangle {
        visible: !parent.flat
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
        visible: !parent.flat
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
