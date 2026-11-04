import QtQuick
import "../config"

// The one panel surface used everywhere: translucent, hairline border.
Rectangle {
    radius: Theme.radius + 4
    color: Theme.glass
    border { color: Theme.line; width: 1 }
    clip: true
    // swallow clicks so the backdrop doesn't close the panel
    MouseArea { anchors.fill: parent }
}
