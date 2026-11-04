import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Overlay {
    id: root
    name: "sidebar"

    property date view: new Date()
    onOpenChanged: if (open) view = new Date()

    function shiftMonth(d) { view = new Date(view.getFullYear(), view.getMonth() + d, 1) }

    Glass {
        id: card
        width: 360
        readonly property real topGap: Theme.margin * 2 + Theme.barHeight
        height: parent.height - topGap - Theme.margin
        y: topGap
        x: root.open ? root.width - width - Theme.margin : root.width + 10
        opacity: root.open ? 1 : 0
        Behavior on x       { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

        Flickable {
            anchors.fill: parent
            contentHeight: col.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                x: 20; y: 20
                width: parent.width - 40
                spacing: 20

                // Date header
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: 40; weight: Font.Light }
                    }
                    Text {
                        text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize + 1 }
                    }
                }

                // Media
                Rectangle {
                    Layout.fillWidth: true
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

                // Calendar
                Column {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: Qt.formatDateTime(root.view, "MMMM yyyy")
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: Theme.fontSize + 1; bold: true }
                        }
                        IconButton { size: 28; icon: ""; onClicked: root.shiftMonth(-1) }
                        IconButton { size: 28; icon: ""; onClicked: root.shiftMonth(1) }
                    }

                    Grid {
                        id: grid
                        width: parent.width
                        columns: 7
                        readonly property real cell: width / 7
                        readonly property int offset: (new Date(root.view.getFullYear(), root.view.getMonth(), 1).getDay() + 6) % 7
                        readonly property int days: new Date(root.view.getFullYear(), root.view.getMonth() + 1, 0).getDate()
                        readonly property var today: new Date()

                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            delegate: Text {
                                required property string modelData
                                width: grid.cell; height: 24
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Theme.fgDim
                                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                            }
                        }
                        Repeater {
                            model: 42
                            delegate: Item {
                                required property int index
                                readonly property int day: index - grid.offset + 1
                                readonly property bool valid: day >= 1 && day <= grid.days
                                readonly property bool isToday: valid && day === grid.today.getDate()
                                    && root.view.getMonth() === grid.today.getMonth()
                                    && root.view.getFullYear() === grid.today.getFullYear()
                                width: grid.cell; height: 34
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30; height: 30; radius: 15
                                    color: parent.isToday ? Theme.accent : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.valid ? parent.day : ""
                                    color: parent.isToday ? Theme.accentFg : Theme.fg
                                    font { family: Theme.font; pixelSize: Theme.fontSize }
                                }
                            }
                        }
                    }
                }

                // System
                Column {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: [
                            { icon: "", label: "CPU", v: Stats.cpu },
                            { icon: "", label: "Memory", v: Stats.mem }
                        ]
                        delegate: Row {
                            id: stat
                            required property var modelData
                            width: parent.width
                            spacing: 12
                            Icon { anchors.verticalCenter: parent.verticalCenter; text: stat.modelData.icon; color: Theme.fgDim; width: 20 }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20 - 48 - 24; height: 6; radius: 3
                                color: Theme.hover
                                Rectangle {
                                    height: parent.height; radius: 3
                                    width: Math.max(height, parent.width * stat.modelData.v)
                                    color: stat.modelData.v > 0.85 ? Theme.danger : Theme.accent
                                    Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 48; horizontalAlignment: Text.AlignRight
                                text: Math.round(stat.modelData.v * 100) + "%"
                                color: Theme.fgDim
                                font { family: Theme.font; pixelSize: Theme.fontSize }
                            }
                        }
                    }
                }
            }
        }
    }
}
