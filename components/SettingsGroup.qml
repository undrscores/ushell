import QtQuick
import QtQuick.Layouts
import "../config"

// A titled card that holds a few related settings.
//   SettingsGroup { title: "Panels"; SettingRow { ... } SettingRow { ... } }
ColumnLayout {
    id: root
    property string title
    default property alias rows: body.data
    Layout.fillWidth: true
    spacing: 8

    SectionLabel { visible: root.title !== ""; text: root.title; Layout.leftMargin: 4 }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 32
        radius: Theme.radius
        color: Theme.tint
        border { width: 1; color: Theme.line }
        ColumnLayout {
            id: body
            x: 18; y: 16
            width: parent.width - 36
            spacing: 18
        }
    }
}
