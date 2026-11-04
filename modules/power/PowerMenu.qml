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
        { id: "lock", order: 0,     icon: "", label: "Lock",     cmd: ["swaylock", "-f"],                    danger: false },
        { id: "suspend", order: 1,  icon: "", label: "Suspend",  cmd: ["systemctl", "suspend"],              danger: false },
        { id: "logout", order: 2,   icon: "", label: "Log out",  cmd: ["niri", "msg", "action", "quit", "-s"], danger: true },
        { id: "reboot", order: 3,   icon: "", label: "Reboot",   cmd: ["systemctl", "reboot"],               danger: true },
        { id: "shutdown", order: 4, icon: "", label: "Shut down", cmd: ["systemctl", "poweroff"],            danger: true }
    ]

    Glass {
        width: row.implicitWidth + 24
        height: 104
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.3 + (root.open ? 0 : -8)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { NumberAnimation { duration: root.open ? 420 : 200; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.6 } }

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
                    // staggered pop-in
                    property real appear: root.open ? 1 : 0
                    Behavior on appear { SequentialAnimation {
                        PauseAnimation { duration: root.open ? 60 + btn.modelData.order * 45 : 0 }
                        NumberAnimation { duration: root.open ? 380 : 120; easing.type: root.open ? Easing.OutBack : Easing.InQuad; easing.overshoot: 2 }
                    } }
                    opacity: Math.min(1, appear)
                    scale: (ma.pressed ? 0.94 : (ma.containsMouse ? 1.08 : 1)) * (0.5 + 0.5 * appear)
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    SequentialAnimation on rotation {
                        running: btn.isArmed; loops: Animation.Infinite
                        NumberAnimation { to: 3; duration: 90 } NumberAnimation { to: -3; duration: 90 }
                    }
                    onIsArmedChanged: if (!isArmed) rotation = 0

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
