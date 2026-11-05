import Quickshell
import QtQuick
import "../../config"
import "../../services"
import "../../components"

Overlay {
    id: root
    name: "power"

    // Actions live in services/Actions.qml; a destructive one is armed by the first click and runs on the second.
    onOpenChanged: Actions.disarm()

    Glass {
        width: row.implicitWidth + 24
        height: 104
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.3 + (root.open ? 0 : -8)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.8
        Behavior on width   { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { SpringAnimation { spring: root.open ? 3.4 : 6; damping: root.open ? 0.22 : 0.8; epsilon: 0.002 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: Actions.power
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool isArmed: Actions.armed === modelData.id
                    width: 80; height: 80
                    radius: Theme.radius
                    color: isArmed ? Theme.dangerSoft : (ma.containsMouse ? Theme.hover : Theme.tint)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    // staggered pop-in
                    property real appear: root.open ? 1 : 0
                    Behavior on appear { SequentialAnimation {
                        PauseAnimation { duration: root.open ? 60 + btn.index * 45 : 0 }
                        NumberAnimation { duration: root.open ? 560 : 120; easing.type: root.open ? Easing.OutBack : Easing.InQuad; easing.overshoot: 4 }
                    } }
                    opacity: Math.min(1, appear)
                    scale: (ma.pressed ? 0.9 : (ma.containsMouse ? 1.12 : 1)) * (0.4 + 0.6 * appear)
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.5 } }
                    SequentialAnimation on rotation {
                        running: btn.isArmed; loops: Animation.Infinite
                        NumberAnimation { to: 3; duration: 90 } NumberAnimation { to: -3; duration: 90 }
                    }
                    onIsArmedChanged: if (!isArmed) rotation = 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; size: 22
                               text: btn.modelData.glyph; color: btn.isArmed ? Theme.danger : Theme.fg }
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
                            if (!Actions.trigger(btn.modelData)) return
                            Shell.close()
                        }
                    }
                }
            }
        }
    }
}
