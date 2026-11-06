import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../config"
import "../services"

// One notification: icon, app, summary, body and its action buttons. Used by the popup stack (popup: true,
// hides itself after a while, paused while the pointer is on it) and by the history panel.
//   left click: the "default" action if the sender gave one, otherwise just closes the popup
//   right / middle click, or the x in the history: remove it for good
Glass {
    id: card
    required property var notification         // a Quickshell Notification
    property bool popup: false

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property bool hovered: hover.hovered
    property bool shown: !popup                // drives the slide / fade in and out (history cards are simply there)

    width: 360
    implicitHeight: content.implicitHeight + 24
    height: implicitHeight
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
    transform: Translate { x: card.shown ? 0 : 48; Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } } }
    Component.onCompleted: shown = true

    // Popups fade out first, then leave the stack. Everything else is removed on the spot.
    function leave() { shown = false; leaveTimer.restart() }
    Timer { id: leaveTimer; interval: Theme.animNormal; onTriggered: if (card.notification) Notifications.hide(card.notification) }

    Timer {
        interval: Notifications.timeoutMs(card.notification)
        running: card.popup && card.shown && interval > 0 && !card.hovered
        onTriggered: card.leave()
    }
    HoverHandler { id: hover }

    readonly property var defaultAction: {
        const a = notification.actions
        for (let i = 0; i < a.length; i++) if (a[i].identifier === "default") return a[i]
        return null
    }
    function activate() {
        if (defaultAction) Notifications.invoke(notification, defaultAction)
        else if (popup) leave()
    }

    // the sender's picture, else its icon, else the icon of its desktop entry
    readonly property string imageSource: {
        const n = notification
        if (n.image && n.image !== "") return n.image
        let icon = n.appIcon || ""
        const key = n.desktopEntry || n.appName
        if (icon === "" && key) { const e = DesktopEntries.heuristicLookup(key); icon = e ? (e.icon || "") : "" }
        if (icon === "") return ""
        if (icon.startsWith("/")) return "file://" + icon
        if (icon.startsWith("file:") || icon.startsWith("image:")) return icon
        return Quickshell.iconPath(icon, true)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) card.activate()
            else Notifications.dismiss(card.notification)
        }
    }

    Rectangle {   // urgent ones get a coloured edge
        visible: card.critical
        width: 3; radius: 1.5
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10; leftMargin: 4 }
        color: Theme.danger
    }

    RowLayout {
        id: content
        x: 12; y: 12
        width: card.width - 24
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40; Layout.preferredHeight: 40
            radius: 10
            color: Theme.tint
            clip: true
            Image {
                anchors.fill: parent
                visible: card.imageSource !== ""
                source: card.imageSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Icon { anchors.centerIn: parent; visible: card.imageSource === ""; text: ""; size: 18; color: Theme.fgDim }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: card.notification.appName
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
                Text {
                    text: Notifications.ago(card.notification)
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
                Icon {   // popup: hide it (it stays in the history); history: delete it
                    text: ""; size: 11
                    color: closeArea.containsMouse ? Theme.fg : Theme.fgDim
                    MouseArea {
                        id: closeArea
                        anchors { fill: parent; margins: -6 }
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: card.popup ? card.leave() : Notifications.dismiss(card.notification)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.summary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 3 : 6
                elide: Text.ElideRight
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                Repeater {
                    model: card.notification.actions
                    delegate: Pill {
                        required property var modelData
                        visible: modelData.identifier !== "default"
                        label: modelData.text
                        onClicked: Notifications.invoke(card.notification, modelData)
                    }
                }
                Pill {   // history only: stop this app's popups
                    visible: !card.popup && card.notification.appName !== ""
                    readonly property bool muted: Notifications.isMuted(card.notification.appName)
                    label: (muted ? "Unmute " : "Mute ") + card.notification.appName
                    active: muted
                    onClicked: muted ? Notifications.unmute(card.notification.appName) : Notifications.mute(card.notification.appName)
                }
            }
        }
    }
}
