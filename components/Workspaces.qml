import QtQuick
import Quickshell
import "../config"
import "../services"

// Workspace dots for the bar: the focused one stretches into a pill, ones with windows are brighter.
// Click to jump, scroll to step through them. Hidden when there is only one workspace.
Item {
    id: root
    visible: wsModel.count > 1
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 30

    // rows are updated in place so the delegates (and their springs) survive the frequent re-sends
    ListModel { id: wsModel }
    function sync() {
        const list = Wm.workspaces
        while (wsModel.count > list.length) wsModel.remove(wsModel.count - 1)
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            const r = { wsIdx: w.idx, focused: w.is_focused === true || w.is_active === true, hasWindow: !!w.active_window_id }
            if (i < wsModel.count) wsModel.set(i, r)
            else wsModel.append(r)
        }
    }
    Connections { target: Wm; function onWorkspacesChanged() { root.sync() } }
    Component.onCompleted: sync()

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            if (cool.running || e.angleDelta.y === 0) return
            Wm.stepWorkspace(e.angleDelta.y < 0 ? 1 : -1)
            cool.restart()
        }
    }
    Timer { id: cool; interval: 180 }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        Repeater {
            model: wsModel
            delegate: Item {
                id: ws
                required property int wsIdx
                required property bool focused
                required property bool hasWindow
                width: focused ? 24 : 9
                height: 30
                Behavior on width { Spring { preset: "glide" } }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 8; radius: 4
                    color: ws.focused ? Theme.accent : (ws.hasWindow ? Theme.fgDim : Theme.surfaceHi)
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Wm.focusWorkspace(ws.wsIdx) }
            }
        }
    }
}
