import QtQuick
import QtQuick.Layouts
import "../config"

Column {
    id: root
    property date view: new Date()
    function shift(d) { view = new Date(view.getFullYear(), view.getMonth() + d, 1) }
    Component.onCompleted: view = new Date()
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
                Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15
                            color: parent.isToday ? Theme.accent : "transparent" }
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
