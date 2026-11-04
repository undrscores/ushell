import QtQuick
import "../config"
import "../services"

Rectangle {
    visible: Media.available
    height: 76
    radius: Theme.radius
    color: Theme.tint

    Rectangle {
        id: art
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 56; height: 56; radius: Theme.radiusSmall + 2
        color: Theme.hover
        clip: true
        Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true }
    }
    Column {
        anchors { left: art.right; leftMargin: 12; right: ctrl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        Text { width: parent.width; elide: Text.ElideRight; text: Media.title || "Nothing playing"
               color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize + 1 } }
        Text { width: parent.width; elide: Text.ElideRight; text: Media.artist
               color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } }
    }
    Row {
        id: ctrl
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 4
        IconButton { size: 30; icon: ""; onClicked: Media.prev() }
        IconButton { size: 30; icon: Media.playing ? "" : ""; active: true; onClicked: Media.toggle() }
        IconButton { size: 30; icon: ""; onClicked: Media.next() }
    }
}
