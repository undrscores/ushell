import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Clipboard history: search, click to copy, pin, delete.
Item {
    id: page
    property bool clearArmed: false
    property bool imagesArmed: false
    readonly property bool hasImages: Clipboard.items.some(i => i.type === "image" && i.pinned !== true)
    onHasImagesChanged: if (!hasImages) imagesArmed = false
    property bool active: true
    property alias contentHeight: list.contentHeight
    onActiveChanged: if (!active) { search.text = ""; search.focus = false }
    readonly property var filtered: {
        const q = search.text.trim().toLowerCase()
        return q === "" ? Clipboard.items : Clipboard.items.filter(i => i.text.toLowerCase().includes(q))
    }

    function ago(t) {
        const s = Math.max(0, Date.now() / 1000 - t)
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }

    // search + clear
    RowLayout {
        id: top
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 8
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.radius
            color: Theme.tint
            border { width: 1; color: search.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
            Icon { id: sic; anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: ""; size: 13; color: Theme.fgDim }
            TextInput {
                id: search
                anchors { left: sic.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                color: Theme.fg
                selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                clip: true
                font { family: Theme.font; pixelSize: Theme.fontSize }
                Keys.onEscapePressed: { if (text !== "") text = ""; else Shell.close() }
                Text { visible: !search.text; text: "Search history"; color: Theme.fgDim; font: search.font }
            }
        }
        Rectangle {   // clear only the (unpinned) images: they are the bulky part of the history
            id: imgBtn
            visible: page.hasImages
            implicitWidth: 38; implicitHeight: 38
            radius: Theme.radius
            color: page.imagesArmed ? Theme.dangerSoft : (ima.containsMouse ? Theme.hover : Theme.tint)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Icon { anchors.centerIn: parent; text: "\uf03e"; size: 14; color: page.imagesArmed ? Theme.danger : Theme.fgDim }
            Timer { id: imgDisarm; interval: 2500; onTriggered: page.imagesArmed = false }
            MouseArea {
                id: ima
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (page.imagesArmed) { Clipboard.clearImages(); page.imagesArmed = false; imgDisarm.stop() }
                    else { page.imagesArmed = true; imgDisarm.restart() }
                }
            }
        }
        Rectangle {
            id: clearBtn
            implicitWidth: 38; implicitHeight: 38
            radius: Theme.radius
            color: page.clearArmed ? Theme.dangerSoft : (cma.containsMouse ? Theme.hover : Theme.tint)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            scale: cma.pressed ? 0.9 : (cma.containsMouse ? 1.08 : 1)
            Behavior on scale { Bounce {} }
            Icon { anchors.centerIn: parent; text: ""; size: 14; color: page.clearArmed ? Theme.danger : Theme.fgDim }
            Timer { id: disarm; interval: 2500; onTriggered: page.clearArmed = false }
            MouseArea {
                id: cma
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (page.clearArmed) { Clipboard.clear(); page.clearArmed = false; disarm.stop() }
                    else { page.clearArmed = true; disarm.restart() }
                }
            }
        }
    }

    ListView {
        id: list
        anchors { top: top.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom }
        model: page.filtered
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entry
            required property var modelData
            required property int index
            property bool flash: false
            width: list.width
            readonly property bool isImage: modelData.type === "image"
            height: isImage ? 76 : Math.max(46, preview.implicitHeight + 22)
            radius: Theme.radius
            color: flash ? Theme.accentSoft : (ema.containsMouse ? Theme.hover : Theme.tint)
            Behavior on color { ColorAnimation { duration: entry.flash ? 80 : 220 } }
            Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

            Timer { id: unflash; interval: 900; onTriggered: entry.flash = false }

            Rectangle {   // pinned marker
                visible: entry.modelData.pinned === true
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
                width: 3; radius: 1.5; color: Theme.accent
            }
            Rectangle {   // image entries: a small thumbnail, the label goes beside it
                id: thumb
                visible: entry.isImage
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 104; height: 56
                radius: Theme.radiusSmall
                color: Qt.rgba(0, 0, 0, 0.25)
                clip: true
                Image {
                    anchors { fill: parent; margins: 2 }
                    source: entry.isImage ? Clipboard.imageUrl(entry.modelData) : ""
                    sourceSize: Qt.size(208, 112)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
            Text {
                id: preview
                anchors { left: entry.isImage ? thumb.right : parent.left; leftMargin: entry.isImage ? 12 : 14; right: side.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: entry.modelData.text.trim().replace(/[ \t]+/g, " ")
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                color: entry.isImage ? Theme.fgDim : Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
            Item {
                id: side
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 52; height: 24
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: ema.containsMouse ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    text: entry.flash ? "copied" : page.ago(entry.modelData.time)
                    color: entry.flash ? Theme.ok : Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    opacity: ema.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    Rectangle {
                        width: 24; height: 24; radius: 8
                        color: pma.containsMouse ? Theme.hover : "transparent"
                        Icon { anchors.centerIn: parent; text: ""; size: 11; color: entry.modelData.pinned ? Theme.accent : Theme.fgDim
                               rotation: entry.modelData.pinned ? 0 : 45 }
                        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Clipboard.togglePin(entry.modelData.id) }
                    }
                    Rectangle {
                        width: 24; height: 24; radius: 8
                        color: dma.containsMouse ? Theme.dangerSoft : "transparent"
                        Icon { anchors.centerIn: parent; text: ""; size: 11; color: dma.containsMouse ? Theme.danger : Theme.fgDim }
                        MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Clipboard.remove(entry.modelData.id) }
                    }
                }
            }
            MouseArea {
                id: ema
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { Clipboard.copy(entry.modelData.id); entry.flash = true; unflash.restart() }
            }
        }

        // empty state
        Column {
            anchors.centerIn: parent
            visible: list.count === 0
            spacing: 10
            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: ""; size: 30; color: Theme.fgDim; opacity: 0.6 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: search.text !== "" ? "No matches" : "Nothing copied yet"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }
    }
}
