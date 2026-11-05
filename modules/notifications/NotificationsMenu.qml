import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Notification history under the top pill: Do Not Disturb, clear all, and every message since the shell
// started. Esc or a click outside closes it.
Overlay {
    id: root
    name: "notifications"
    onOpenChanged: if (open) Notifications.markRead()

    DropCard {
        id: card
        open: root.open
        contentWidth: 384
        contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "Notifications"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 2; bold: true }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Do not disturb"
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                }
                Switch { checked: Notifications.dnd; onToggled: v => Notifications.setDnd(v) }
                Pill { visible: Notifications.count > 0; label: "Clear"; onClicked: Notifications.clear() }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 480)
                visible: Notifications.count > 0
                model: Notifications.history
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    width: list.width
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6; Layout.bottomMargin: 10
                visible: Notifications.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Notifications.dnd ? "Nothing new, and Do Not Disturb is on" : "Nothing new"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }
    }
}
