import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Pinned apps (cards) + everything currently open.
Flickable {
    id: page
    contentHeight: col.implicitHeight + 8
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function label(text) { return text }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 10

        Text { text: "Pinned"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2; letterSpacing: 0.6 } }

        Grid {
            Layout.fillWidth: true
            columns: 2
            spacing: 8
            readonly property real cell: (width - spacing) / 2
            Repeater {
                model: Config.pinnedApps
                delegate: Rectangle {
                    id: card
                    required property string modelData
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                    readonly property bool running: Niri.appWindow(entry) !== null
                    visible: entry !== null
                    width: parent.cell; height: visible ? 54 : 0
                    radius: Theme.radius
                    color: cma.containsMouse ? Theme.hover : Theme.tint
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    scale: cma.pressed ? 0.94 : (cma.containsMouse ? 1.04 : 1)
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 } }
                    transform: Translate { id: hop }
                    SequentialAnimation {
                        id: bounce
                        NumberAnimation { target: hop; property: "y"; to: -7; duration: 110; easing.type: Easing.OutQuad }
                        NumberAnimation { target: hop; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBounce }
                    }

                    Image {
                        id: ic
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 30; height: 30
                        sourceSize: Qt.size(60, 60)
                        source: card.entry ? Quickshell.iconPath(card.entry.icon, "application-x-executable") : ""
                    }
                    Text {
                        anchors { left: ic.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: card.entry ? card.entry.name : ""
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    }
                    Rectangle {  // running dot
                        anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 8 }
                        width: card.running ? 7 : 0; height: width; radius: width / 2
                        color: Theme.accent
                        Behavior on width { SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.2 } }
                    }
                    MouseArea {
                        id: cma
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bounce.restart()
                            const w = Niri.appWindow(card.entry)
                            if (w) Niri.focusWindow(w.id); else if (card.entry) card.entry.execute()
                        }
                    }
                }
            }
        }

        // Running windows
        Text {
            visible: Niri.windows.length > 0
            Layout.topMargin: 6
            text: "Open"
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2; letterSpacing: 0.6 }
        }

        Repeater {
            model: Niri.windows
            delegate: Rectangle {
                id: win
                required property var modelData
                readonly property var entry: DesktopEntries.heuristicLookup(modelData.app_id)
                readonly property string iconSrc: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
                Layout.fillWidth: true
                implicitHeight: 46
                radius: Theme.radius
                color: modelData.is_focused ? Theme.accentSoft : (wma.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Item {
                    id: wicon
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 26; height: 26
                    Image { anchors.fill: parent; visible: win.iconSrc !== ""; source: win.iconSrc; sourceSize: Qt.size(52, 52) }
                    Icon { anchors.centerIn: parent; visible: win.iconSrc === ""; text: ""; color: Theme.fgDim }
                }
                Column {
                    anchors { left: wicon.right; leftMargin: 10; right: closeBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: win.modelData.title || win.modelData.app_id || "Window"
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: win.entry ? win.entry.name : (win.modelData.app_id || "")
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
                    }
                }
                Rectangle {
                    id: closeBtn
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 26; height: 26; radius: 9
                    opacity: wma.containsMouse ? 1 : 0
                    scale: opacity > 0 ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                    color: xma.containsMouse ? Qt.rgba(0.953, 0.545, 0.659, 0.28) : Theme.tint
                    Icon { anchors.centerIn: parent; text: ""; size: 11; color: xma.containsMouse ? Theme.danger : Theme.fgDim }
                    MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Niri.closeWindow(win.modelData.id) }
                }
                MouseArea {
                    id: wma
                    anchors.fill: parent
                    z: -1
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) Niri.closeWindow(win.modelData.id)
                        else Niri.focusWindow(win.modelData.id)
                    }
                }
            }
        }

        // All apps -> launcher
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 40
            radius: Theme.radius
            color: lma.containsMouse ? Theme.hover : Theme.tint
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Row {
                anchors.centerIn: parent
                spacing: 8
                Icon { anchors.verticalCenter: parent.verticalCenter; text: ""; size: 13; color: Theme.fgDim }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "All apps"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } }
            }
            MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("launcher") }
        }
    }
}
