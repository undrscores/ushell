import QtQuick
import QtQuick.Layouts
import "../config"

Column {
    id: root
    property date view: new Date()
    property date today: new Date()
    function shift(d) { view = new Date(view.getFullYear(), view.getMonth() + d, 1) }
    // The calendar lives as long as the shell does: call this when it opens so "today" and the month are current.
    function reset() { today = new Date(); view = today }
    Component.onCompleted: reset()
    spacing: 8

    RowLayout {
        width: parent.width
        Text {
            Layout.fillWidth: true
            text: Qt.formatDateTime(root.view, "MMMM yyyy")
            color: Theme.fg
            font { family: Theme.font; pixelSize: Theme.fontSize + 1; bold: true }
        }
        IconButton { size: 28; icon: ""; onClicked: root.shift(-1) }
        IconButton { size: 28; icon: ""; onClicked: root.shift(1) }
    }

    Grid {
        id: grid
        width: parent.width
        columns: 7
        readonly property real cell: width / 7
        readonly property int offset: (new Date(root.view.getFullYear(), root.view.getMonth(), 1).getDay() + 6) % 7
        readonly property int days: new Date(root.view.getFullYear(), root.view.getMonth() + 1, 0).getDate()

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
                readonly property bool isToday: valid && day === root.today.getDate()
                    && root.view.getMonth() === root.today.getMonth()
                    && root.view.getFullYear() === root.today.getFullYear()
                width: grid.cell; height: 34
                Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15
                            color: parent.isToday ? Theme.accent : (dayMa.containsMouse && parent.valid ? Theme.hover : "transparent")
                            scale: dayMa.containsMouse && parent.valid ? 1.12 : 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 } } }
                MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
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
