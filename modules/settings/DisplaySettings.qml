import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Display: resolution, refresh rate and scale of each monitor (uwm only; talks to its IPC socket).
// Every change is kept only if you confirm it within a few seconds.
ColumnLayout {
    spacing: 22

    Text {
        visible: !Uwm.available
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fgDim
        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
        text: "Display settings talk to uwm and need $UWM_SOCKET, which is only set when the shell runs inside a uwm session."
    }

    Text {
        visible: Uwm.available && !Uwm.connected
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fgDim
        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
        text: "Waiting for uwm ..."
    }

    Repeater {
        model: Uwm.monitors

        SettingsGroup {
            id: group
            required property var modelData
            readonly property var cur: Uwm.modeOf(modelData)
            // the resolution being browsed; follows the live mode until one is picked
            property string picked: ""
            readonly property string resKey: picked !== "" ? picked : (cur ? cur.width + "x" + cur.height : "")
            readonly property var resList: Uwm.resolutions(modelData)
            readonly property var resNow: resList.find(r => r.key === resKey) ?? null

            title: modelData.name + (cur ? "  ·  " + cur.width + "×" + cur.height + " @ " + Uwm.hzText(cur.refresh) : "") + "  ·  scale " + modelData.scale

            Text {
                visible: group.resList.length === 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                text: "This output reports no modes (a nested or virtual display), so only the scale can be changed."
            }

            SettingRow {
                visible: group.resList.length > 0
                icon: ""; title: "Resolution"; hint: "Picking one uses its highest refresh rate"
                Item {}
            }
            Flow {
                visible: group.resList.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 40
                spacing: 6
                Repeater {
                    model: group.resList.slice(0, 10)
                    delegate: Pill {
                        required property var modelData
                        label: modelData.width + "×" + modelData.height
                        active: modelData.key === group.resKey
                        onClicked: { group.picked = modelData.key; Uwm.setMode(group.modelData, modelData.width, modelData.height, 0) }
                    }
                }
            }

            SettingRow {
                visible: group.resNow !== null
                icon: ""; title: "Refresh rate"; hint: "For " + (group.resNow ? group.resNow.width + "×" + group.resNow.height : "")
                Item {}
            }
            Flow {
                visible: group.resNow !== null
                Layout.fillWidth: true
                Layout.leftMargin: 40
                spacing: 6
                Repeater {
                    model: group.resNow ? Uwm.rates(group.modelData, group.resNow.width, group.resNow.height) : []
                    delegate: Pill {
                        required property var modelData
                        label: Uwm.hzText(modelData.refresh)
                        active: modelData.current
                        onClicked: Uwm.setMode(group.modelData, modelData.width, modelData.height, modelData.refresh)
                    }
                }
            }

            SettingRow {
                icon: ""; title: "Scale"; hint: "Windows keep their canvas position; apps are told the new scale"
                Item {}
            }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                spacing: 6
                Repeater {
                    model: [1, 1.25, 1.5, 1.75, 2]
                    delegate: Pill {
                        required property var modelData
                        label: Math.round(modelData * 100) + "%"
                        active: Math.abs(group.modelData.scale - modelData) < 0.01
                        onClicked: Uwm.setScale(group.modelData, modelData)
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: "Brightness"
        visible: Brightness.displays.length > 0 || Brightness.detecting || Brightness.missing
        Component.onCompleted: Brightness.ensure()
        Repeater {
            model: Brightness.displays
            delegate: RowLayout {
                id: br
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                Icon { text: "\uf185"; size: 17; color: Theme.fg; Layout.preferredWidth: 34; horizontalAlignment: Text.AlignHCenter }
                Slider {
                    Layout.fillWidth: true
                    value: br.modelData.value / 100
                    tone: Theme.accent2
                    onMoved: v => Brightness.set(br.modelData.bus, v * 100)
                }
                Text {
                    Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
                    text: Math.round(br.modelData.value); color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                }
            }
        }
        Text {
            visible: Brightness.detecting || Brightness.missing
            text: Brightness.detecting ? "Reading monitor brightness…" : "No DDC monitor found for brightness"
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
        }
    }

    // a change is waiting for confirmation
    Rectangle {
        visible: Uwm.pending !== null
        Layout.fillWidth: true
        implicitHeight: 54
        radius: Theme.radius
        color: Theme.dangerSoft
        border { width: 1; color: Theme.danger }
        Text {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            text: "Keep these display settings?  Reverting in " + (Uwm.pending ? Uwm.pending.left : 0) + " s"
            color: Theme.fg
            font { family: Theme.font; pixelSize: Theme.fontSize + 1 }
        }
        Row {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 6
            Pill { label: "Revert"; onClicked: Uwm.revert() }
            Pill { label: "Keep"; active: true; onClicked: Uwm.keep() }
        }
    }
}
