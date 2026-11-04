import Quickshell
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Thumbnail picker for the wallpaper folder (launcher: "Wallpapers", or `qs ipc call shell toggle wallpapers`).
Overlay {
    id: root
    name: "wallpapers"
    onOpenChanged: if (open) Wallpapers.refresh()

    Glass {
        id: card
        width: Math.min(680, parent.width - 48)
        height: Math.min(460, parent.height - 96)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14 + (root.open ? 0 : -10)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { SpringAnimation { spring: root.open ? 3.4 : 6; damping: root.open ? 0.24 : 0.8; epsilon: 0.002 } }

        component Pill: Rectangle {
            id: pill
            property string label
            signal clicked()
            implicitWidth: pillText.implicitWidth + 24; implicitHeight: 28
            radius: height / 2
            color: pma.containsMouse ? Theme.hover : Theme.tint
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Text { id: pillText; anchors.centerIn: parent; text: pill.label; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } }
            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
        }

        Item {
            anchors { fill: parent; margins: 16 }

            Item {
                id: header
                width: parent.width; height: 28
                Text {
                    id: title
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wallpapers"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 2; bold: true }
                }
                Text {
                    anchors { left: title.right; leftMargin: 10; right: pills.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: Wallpapers.scanned ? Wallpapers.files.length + " in " + Wallpapers.dir.replace(Wallpapers.home, "~") : ""
                    elide: Text.ElideMiddle
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
                Row {
                    id: pills
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Pill { label: "Random"; onClicked: Wallpapers.random() }
                    Pill { label: "Off"; onClicked: Wallpapers.off() }
                }
            }

            GridView {
                id: grid
                anchors { top: header.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Wallpapers.files
                readonly property int cols: Math.max(1, Math.floor(width / 150))
                cellWidth: Math.floor(width / cols)
                cellHeight: Math.round(cellWidth * 0.62)

                delegate: Item {
                    id: cell
                    required property string modelData
                    required property int index
                    readonly property bool chosen: modelData === Wallpapers.current
                    width: grid.cellWidth; height: grid.cellHeight

                    Rectangle {
                        anchors { fill: parent; margins: 4 }
                        radius: Theme.radiusSmall + 2
                        color: Theme.tint
                        clip: true
                        border { width: cell.chosen ? 2 : 0; color: Theme.accent }
                        scale: cma.containsMouse ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                        Image {
                            anchors { fill: parent; margins: cell.chosen ? 2 : 0 }
                            source: Wallpapers.url(cell.modelData)
                            sourceSize: Qt.size(320, 200)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {          // file name, on hover
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 24
                            color: Qt.rgba(0, 0, 0, 0.55)
                            opacity: cma.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                            Text {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                verticalAlignment: Text.AlignVCenter
                                text: Wallpapers.nameOf(cell.modelData)
                                elide: Text.ElideRight
                                color: "white"
                                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                            }
                        }
                        MouseArea {
                            id: cma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.set(cell.modelData)
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: grid
                visible: Wallpapers.scanned && Wallpapers.files.length === 0
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No pictures found"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 1 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Put images in " + Wallpapers.dir.replace(Wallpapers.home, "~") + ",\nor set \"wallpaperDir\" in config.json"
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                }
            }
        }
    }
}
