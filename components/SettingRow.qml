import QtQuick
import QtQuick.Layouts
import "../config"

// One setting: an icon, a title with an optional hint underneath, and the control (a Switch, Pills ...) on the right.
//   SettingRow { icon: ""; title: "Frame"; hint: "..."; Switch { ... } }
RowLayout {
    id: root
    property string title
    property string hint
    property string icon
    default property alias control: slot.data
    Layout.fillWidth: true
    spacing: 14

    Icon {
        visible: root.icon !== ""
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 26; Layout.topMargin: 1
        text: root.icon; size: 17; color: Theme.accent
    }
    Column {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Text { width: parent.width; wrapMode: Text.Wrap; text: root.title; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize + 1 } }
        Text { width: parent.width; wrapMode: Text.Wrap; visible: root.hint !== ""; text: root.hint; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
    }
    Item { id: slot; Layout.alignment: Qt.AlignVCenter; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
}
