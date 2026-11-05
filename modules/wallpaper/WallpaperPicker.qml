import Quickshell
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Thumbnail picker for the wallpaper folder (launcher: "Wallpapers", or `qs ipc call shell toggle wallpapers`).
Overlay {
    id: root
    name: "wallpapers"
    scrim: 0.35
    onOpenChanged: if (open) {
        Wallpapers.refresh()
        Qt.callLater(() => { grid.currentIndex = Math.max(0, Wallpapers.files.indexOf(Wallpapers.current)); grid.positionViewAtIndex(grid.currentIndex, GridView.Center); grid.forceActiveFocus() })
    }

    Glass {
        id: card
        width: Math.min(900, parent.width - 48)
        height: Math.min(580, parent.height - 96)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14 + (root.open ? 0 : -10)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { Spring { preset: root.open ? "popIn" : "popOut"; epsilon: 0.002 } }

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
                    text: Wallpapers.scanned ? Wallpapers.files.length + " wallpapers  ·  ←↑↓→ browse  ·  Enter apply  ·  R random" : ""
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
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                currentIndex: 0
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (currentIndex >= 0 && currentIndex < Wallpapers.files.length) Wallpapers.set(Wallpapers.files[currentIndex])
                        event.accepted = true
                    } else if (event.key === Qt.Key_R) { Wallpapers.random(); event.accepted = true }
                }
                readonly property int cols: Math.max(1, Math.floor(width / 200))
                cellWidth: Math.floor(width / cols)
                cellHeight: Math.round(cellWidth * 0.62)

                delegate: Item {
                    id: cell
                    required property string modelData
                    required property int index
                    readonly property bool chosen: modelData === Wallpapers.current
                    readonly property bool focused: GridView.isCurrentItem
                    width: grid.cellWidth; height: grid.cellHeight

                    // pop in one after another when the picker opens, reset when it closes
                    property bool shown: false
                    opacity: shown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Timer {
                        interval: 40 + Math.min(cell.index, 30) * 32
                        running: root.open
                        onTriggered: cell.shown = true
                    }
                    Connections { target: root; function onOpenChanged() { if (!root.open) cell.shown = false } }

                    Rectangle {
                        anchors { fill: parent; margins: 4 }
                        radius: Theme.radiusSmall + 2
                        color: Theme.tint
                        clip: true
                        border { width: (cell.chosen || cell.focused) ? 2 : 0; color: cell.chosen ? Theme.accent : Theme.fg }
                        readonly property bool lifted: cma.containsMouse || cell.focused
                        scale: !cell.shown ? 0.82 : (lifted ? 1.06 : 1)
                        y: cell.shown ? 0 : 16
                        z: lifted ? 2 : 0
                        Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                        Behavior on border.width { NumberAnimation { duration: Theme.animFast } }

                        Image {
                            anchors { fill: parent; margins: cell.chosen ? 2 : 0 }
                            source: Wallpapers.url(cell.modelData)
                            sourceSize: Qt.size(480, 300)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 400 } }
                        }
                        Rectangle {          // file name, on hover
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 24
                            color: Qt.rgba(0, 0, 0, 0.55)
                            opacity: (cma.containsMouse || cell.focused) ? 1 : 0
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
                            onClicked: { grid.currentIndex = cell.index; Wallpapers.set(cell.modelData) }
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
