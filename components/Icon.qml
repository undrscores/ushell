import QtQuick
import "../config"

Text {
    property int size: Theme.iconSize
    color: Theme.fg
    font { family: Theme.iconFont; pixelSize: size }
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
