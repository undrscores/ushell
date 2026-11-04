import Quickshell
import QtQuick
import "../../config"
import "../../services"
import "../../components"

Overlay {
    id: root
    name: "power"

    // First click arms a destructive action, second click runs it.
    property string armed: ""
    onOpenChanged: armed = ""

    readonly property var actions: [
        { id: "lock",     icon: "", label: "Lock",     cmd: ["swaylock", "-f"],                    danger: false },
        { id: "suspend",  icon: "", label: "Suspend",  cmd: ["systemctl", "suspend"],              danger: false },
        { id: "logout",   icon: "", label: "Log out",  cmd: ["niri", "msg", "action", "quit", "-s"], danger: true },
        { id: "reboot",   icon: "", label: "Reboot",   cmd: ["systemctl", "reboot"],               danger: true },
        { id: "shutdown", icon: "", label: "Shut down", cmd: ["systemctl", "poweroff"],            danger: true }
    ]

    Glass {
        width: row.implicitWidth + 24
        height: 104
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.3 + (root.open ? 0 : -8)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.985
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: root.actions
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    readonly property bool isArmed: root.armed === modelData.id
                    width: 80; height: 80
                    radius: Theme.radius
                    color: isArmed ? Qt.rgba(0.953, 0.545, 0.659, 0.25) : (ma.containsMouse ? Theme.hover : Theme.tint)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    scale: ma.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; size: 22
                               text: btn.modelData.icon; color: btn.isArmed ? Theme.danger : Theme.fg }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.isArmed ? "Confirm" : btn.modelData.label
                            color: btn.isArmed ? Theme.danger : Theme.fgDim
                            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                        }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (btn.modelData.danger && !btn.isArmed) { root.armed = btn.modelData.id; return }
                            Shell.close()
                            Quickshell.execDetached(btn.modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
