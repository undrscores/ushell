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
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14; Layout.bottomMargin: 18
                visible: Notifications.count === 0
                spacing: 10
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 56; height: 56; radius: 28
                    color: Theme.accentSoft
                    Icon { anchors.centerIn: parent; text: Notifications.silent ? "\uf1f6" : "\uf0f3"; size: 24; color: Theme.accent }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "All caught up"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 1; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Notifications.silent ? "Do Not Disturb is on" : "Nothing new"
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                }
            }
        }
    }
}
