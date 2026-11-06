import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Notification centre under the top pill: Do Not Disturb, search, and every message grouped by app (newest first).
// A group with several messages folds up with a click on its title and can be cleared on its own.
// Esc or a click outside closes it.
Overlay {
    id: root
    name: "notifications"
    onOpenChanged: {
        if (open) { Notifications.markRead(); Qt.callLater(() => search.forceActiveFocus()) }
        else { search.text = ""; collapsed = ({}) }
    }

    property var collapsed: ({})                 // app name -> folded up
    readonly property string filter: search.text.trim().toLowerCase()

    // header rows (apps with several messages) and message rows, in display order
    readonly property var rows: {
        const q = filter
        const order = [], groups = {}
        for (const r of Notifications.log) {
            if (q !== "" && !(r.app + " " + r.summary + " " + r.body).toLowerCase().includes(q)) continue
            if (!groups[r.app]) { groups[r.app] = []; order.push(r.app) }
            groups[r.app].push(r)
        }
        const out = []
        for (const app of order) {
            const items = groups[app]
            if (items.length > 1) {
                const folded = q === "" && collapsed[app] === true
                out.push({ kind: "header", app: app, count: items.length, folded: folded })
                if (!folded) for (const r of items) out.push({ kind: "item", rec: r })
            } else out.push({ kind: "item", rec: items[0] })
        }
        return out
    }
    function fold(app) { const c = Object.assign({}, collapsed); c[app] = !c[app]; collapsed = c }

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

            Rectangle {
                visible: Notifications.count > 0
                Layout.fillWidth: true
                height: 34
                radius: Theme.radius
                color: Theme.tint
                Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; text: ""; size: 13; color: Theme.fgDim }
                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 36; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentFg
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    clip: true
                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search notifications"
                        color: Theme.fgDim
                        font: search.font
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 480)
                visible: root.rows.length > 0
                model: root.rows
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: row
                    required property var modelData
                    width: list.width
                    height: loader.item ? loader.item.height : 0
                    Loader {
                        id: loader
                        width: parent.width
                        sourceComponent: row.modelData.kind === "header" ? header : message
                    }
                    Component {
                        id: message
                        NotificationCard {
                            notification: Notifications.view(row.modelData.rec)
                            width: row.width
                        }
                    }
                    Component {
                        id: header
                        Item {
                            width: row.width
                            height: 26
                            Row {
                                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                Icon { anchors.verticalCenter: parent.verticalCenter; text: row.modelData.folded ? "" : ""; size: 10; color: Theme.fgDim }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.app || "Unknown"
                                    color: Theme.fg
                                    font { family: Theme.font; pixelSize: Theme.fontSize - 1; bold: true }
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: countText.implicitWidth + 12; height: 18; radius: 9
                                    color: Theme.accentSoft
                                    Text { id: countText; anchors.centerIn: parent; text: row.modelData.count; color: Theme.accent
                                           font { family: Theme.font; pixelSize: Theme.fontSize - 3; bold: true } }
                                }
                            }
                            MouseArea {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: clearApp.left }
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.filter === ""
                                onClicked: root.fold(row.modelData.app)
                            }
                            Text {
                                id: clearApp
                                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                text: "Clear"
                                color: clearMa.containsMouse ? Theme.fg : Theme.fgDim
                                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                                MouseArea { id: clearMa; anchors { fill: parent; margins: -6 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: Notifications.clearApp(row.modelData.app) }
                            }
                        }
                    }
                }
            }
            Text {
                visible: Notifications.count > 0 && root.rows.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 6; Layout.bottomMargin: 10
                horizontalAlignment: Text.AlignHCenter
                text: "Nothing matches “" + search.text.trim() + "”"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
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
                    Icon { anchors.centerIn: parent; text: Notifications.silent ? "" : ""; size: 24; color: Theme.accent }
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
