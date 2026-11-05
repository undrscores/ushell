import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Bluetooth dropdown (the Bluetooth icon in the top pill, or `qs ipc call shell toggle bluetooth`):
// the adapter switch and the devices around. Click one to connect or disconnect it, or to pair a new one;
// right-click a paired one to forget it. Scans while the menu is open.
Overlay {
    id: root
    name: "bluetooth"

    onOpenChanged: Bt.scan(open)

    DropCard {
        id: card
        open: root.open
        contentWidth: 320
        contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Icon { text: Bt.glyph; size: 20; color: Bt.connectedCount > 0 ? Theme.accent : Theme.fgDim; Layout.preferredWidth: 28 }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: "Bluetooth"
                        color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: !Bt.available ? "No adapter, or bluetooth is not running"
                            : !Bt.on ? "Off"
                            : Bt.connectedCount > 0 ? Bt.connectedCount + " connected" : (Bt.scanning ? "Scanning…" : "Not connected")
                        color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                    }
                }
                Pill { visible: Bt.on; label: Bt.scanning ? "Stop" : "Scan"; onClicked: Bt.scan(!Bt.scanning) }
                Switch { visible: Bt.available; checked: Bt.on; onToggled: v => Bt.setOn(v) }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: Bt.on
                spacing: 8
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
                SectionLabel { text: "Devices" }
                Text {
                    Layout.fillWidth: true
                    visible: Bt.devices.length === 0
                    text: "Nothing found yet. Put the device in pairing mode."
                    wrapMode: Text.Wrap
                    color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: Bt.devices
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                            width: parent.width; height: 46
                            radius: Theme.radiusSmall + 2
                            color: modelData.connected ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Connections {          // a click on a new device pairs it; connect once that worked
                                target: row.modelData
                                function onPairedChanged() {
                                    if (row.modelData.paired && !row.modelData.connected && Bt.pending === row.modelData.address) {
                                        Bt.pending = ""
                                        row.modelData.connect()
                                    }
                                }
                            }
                            Icon {
                                id: ic
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                width: 22; text: ""; size: 16
                                color: row.modelData.connected ? Theme.accent : Theme.fgDim
                            }
                            Column {
                                anchors { left: ic.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                spacing: 1
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: Bt.label(row.modelData)
                                    color: row.modelData.connected ? Theme.fg : Theme.fgDim
                                    font { family: Theme.font; pixelSize: Theme.fontSize }
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: row.busy ? (row.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Disconnecting…")
                                        : [row.modelData.connected ? "Connected" : (row.modelData.paired ? "Paired" : "New"),
                                           row.modelData.batteryAvailable ? Math.round(row.modelData.battery * 100) + "%" : ""].filter(x => x).join(" · ")
                                    color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                                }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) { if (row.modelData.paired) row.modelData.forget() }
                                    else if (!row.busy) Bt.toggle(row.modelData)
                                }
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Click to connect or pair · right-click to forget"
                    color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
                }
            }
        }
    }
}
