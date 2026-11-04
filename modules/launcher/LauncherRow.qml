import Quickshell
import QtQuick
import "../../config"
import "../../components"

// One result row in the launcher list.
Item {
    id: row
    required property var modelData
    required property int index
    property bool fresh: false      // the list just opened: stagger the entrance
    property string armed: ""       // id of the action waiting for a second Enter
    signal hovered()
    signal activated()
    readonly property bool armedNow: modelData.kind === "action" && row.armed === modelData.id
    readonly property string iconSrc: (modelData.icon ?? "") !== "" ? Quickshell.iconPath(modelData.icon, true) : ""
    readonly property bool useImage: iconSrc !== ""
    height: 40
    z: 1
    opacity: 0
    transform: Translate { id: slideIn; x: row.fresh ? -14 : 0 }
    Component.onCompleted: appear.start()
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: row.fresh ? Math.min(row.index, 9) * 26 : 0 }
        ParallelAnimation {
            NumberAnimation { target: row; property: "opacity"; to: 1; duration: row.fresh ? 220 : 90 }
            NumberAnimation { target: slideIn; property: "x"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
    }

    Item {
        id: icon
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 24; height: 24
        Image {
            anchors.fill: parent
            visible: row.useImage
            sourceSize: Qt.size(60, 60)
            source: row.iconSrc
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            visible: !row.useImage
            radius: Theme.radiusSmall
            color: row.modelData.kind === "calc" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                : row.armedNow ? Theme.dangerSoft : Qt.rgba(1, 1, 1, 0.08)
            Icon {
                anchors.centerIn: parent
                text: row.modelData.glyph ?? "\uf2d0"
                size: 13
                color: row.modelData.kind === "calc" ? Theme.accent : (row.armedNow ? Theme.danger : Theme.fgDim)
            }
        }
    }

    Text {
        id: tag
        visible: text !== ""
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, parent.width * 0.4)
        elide: Text.ElideLeft
        horizontalAlignment: Text.AlignRight
        text: row.modelData.kind === "pkg" ? (row.modelData.installed ? "installed" : "") : (row.modelData.tag ?? "")
        color: row.modelData.kind === "pkg" ? Theme.ok : Theme.fgDim
        opacity: row.modelData.kind === "pkg" ? 1 : 0.7
        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
    }

    Text {
        anchors { left: icon.right; leftMargin: 12; right: tag.visible ? tag.left : parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: row.armedNow ? "Press Enter again to confirm" : row.modelData.title
        color: row.armedNow ? Theme.danger : (row.modelData.kind === "calc" ? Theme.accent : Theme.fg)
        font { family: Theme.font; pixelSize: row.modelData.kind === "calc" ? Theme.fontSize + 3 : Theme.fontSize }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: row.hovered()
        onClicked: row.activated()
    }
}

