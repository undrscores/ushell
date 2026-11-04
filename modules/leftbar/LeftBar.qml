import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Left dock, macOS-style: compact, icons grow toward the pointer, running apps get a dot.
// Pinned apps (config/Config.qml) first, then any other open app. Auto-hides; the pin
// button keeps it always visible (and reserves its space).
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "left"
        autoHide: Prefs.leftAutoHide
        panelWidth: Theme.dockWidth
        panelHeight: col.implicitHeight + 28
        panelRadius: 24

        // ── what the dock shows ───────────────────────────────────────────
        // pinned apps in config order, then one icon per other open app
        // Both models below are only replaced when what they show actually changed. Niri re-sends
        // fresh JSON on every event (window titles change all the time), and a Repeater over a
        // replaced JS array rebuilds every delegate: icons would re-pop and the workspace pills
        // could never animate.
        property var items: []
        property string itemsSig: ""
        function rebuildItems() {
            const out = []
            const pinnedIds = []
            for (const name of Config.pinnedApps) {
                const e = DesktopEntries.heuristicLookup(name)
                if (!e) continue
                pinnedIds.push([e.id, e.startupClass, e.name].filter(x => x).map(x => x.toLowerCase()))
                out.push({ key: "p:" + e.id, entry: e, name: e.name, icon: e.icon, pinned: true })
            }
            const seen = {}
            for (const w of Niri.windows) {
                const id = (w.app_id || "").toLowerCase()
                if (!id || seen[id] || pinnedIds.some(ids => ids.includes(id))) continue
                seen[id] = true
                const e = DesktopEntries.heuristicLookup(w.app_id)
                out.push({ key: "w:" + id, entry: e, name: e ? e.name : (w.app_id || w.title), icon: e ? e.icon : "", pinned: false })
            }
            const sig = out.map(o => o.key + "|" + o.name + "|" + o.icon + "|" + (o.entry ? 1 : 0)).join(";")
            if (sig === itemsSig) return
            itemsSig = sig
            items = out
        }

        // workspace pills: rows updated in place so the delegates (and their springs) survive
        ListModel { id: wsModel }
        function syncWorkspaces() {
            const list = Niri.workspaces
            while (wsModel.count > list.length) wsModel.remove(wsModel.count - 1)
            for (let i = 0; i < list.length; i++) {
                const w = list[i]
                const row = { wsIdx: w.idx, focused: w.is_focused === true || w.is_active === true, hasWindow: !!w.active_window_id }
                if (i < wsModel.count) wsModel.set(i, row)
                else wsModel.append(row)
            }
        }
        Connections {
            target: Niri
            function onWindowsChanged() { win.rebuildItems() }
            function onWorkspacesChanged() { win.syncWorkspaces() }
        }
        Connections {
            target: DesktopEntries.applications
            function onValuesChanged() { win.rebuildItems() }   // entries finish loading after the first window event
        }
        Component.onCompleted: { rebuildItems(); syncWorkspaces() }

        Item {
            id: dock
            anchors.fill: parent

            // pointer position within the dock, for magnification
            HoverHandler { id: dockHover }
            readonly property real pointerY: dockHover.hovered ? dockHover.point.position.y : -1000

            Column {
                id: col
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                spacing: 8

                // workspaces
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    // scroll over the pills to move between workspaces
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: e => {
                            if (wsCool.running || e.angleDelta.y === 0) return
                            Quickshell.execDetached(["niri", "msg", "action", e.angleDelta.y < 0 ? "focus-workspace-down" : "focus-workspace-up"])
                            wsCool.restart()
                        }
                    }
                    Timer { id: wsCool; interval: 180 }
                    Repeater {
                        model: wsModel
                        delegate: Item {
                            id: ws
                            required property int wsIdx
                            required property bool focused
                            required property bool hasWindow
                            readonly property bool active: focused
                            width: 30; height: active ? 28 : 13
                            Behavior on height { SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.3 } }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 18; height: parent.height + 6; radius: 9
                                color: Theme.accent
                                opacity: ws.active ? 0.2 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8; height: parent.height - 3; radius: 4
                                color: ws.active ? Theme.accent : (ws.hasWindow ? Theme.fgDim : Theme.surfaceHi)
                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(ws.wsIdx) }
                        }
                    }
                }

                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 28; height: 1; color: Theme.line }

                // apps
                Repeater {
                    model: win.items
                    delegate: Item {
                        id: slot
                        required property var modelData
                        readonly property var win_: modelData.entry ? Niri.appWindow(modelData.entry)
                                                  : Niri.windows.find(w => (w.app_id || "").toLowerCase() === modelData.key.slice(2)) ?? null
                        readonly property bool running: win_ !== null && win_ !== undefined
                        readonly property string iconSrc: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        property real appear: 0
                        readonly property real magnify: {
                            const cy = slot.mapToItem(dock, 0, slot.height / 2).y
                            const d = Math.abs(dock.pointerY - cy)
                            return 1 + 0.42 * Math.pow(Math.max(0, 1 - d / 88), 1.6)
                        }
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48; height: 44 * Math.min(1, appear)
                        Component.onCompleted: appear = 1
                        Behavior on appear { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                        z: ima.containsMouse ? 3 : 0

                        Item {
                            id: iconWrap
                            anchors.centerIn: parent
                            width: 38; height: 38
                            scale: ima.pressed ? 0.86 : slot.magnify * Math.max(0.01, slot.appear)
                            opacity: Math.min(1, slot.appear)
                            Behavior on scale { SpringAnimation { spring: 7; damping: 0.55; epsilon: 0.002 } }
                            transform: Translate { id: hop }
                            SequentialAnimation {
                                id: bounce
                                NumberAnimation { target: hop; property: "y"; to: -9; duration: 120; easing.type: Easing.OutQuad }
                                NumberAnimation { target: hop; property: "y"; to: 0; duration: 480; easing.type: Easing.OutBounce }
                            }
                            Image {
                                anchors.fill: parent
                                visible: slot.iconSrc !== ""
                                source: slot.iconSrc
                                sourceSize: Qt.size(96, 96)
                                mipmap: true; smooth: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: slot.iconSrc === ""
                                radius: 11
                                color: Theme.surface
                                Icon { anchors.centerIn: parent; text: ""; size: 18; color: Theme.fgDim }
                            }
                        }
                        Rectangle {   // running dot, on the screen-edge side like a dock indicator
                            anchors { left: parent.left; leftMargin: 1; verticalCenter: parent.verticalCenter }
                            width: 4; radius: 2
                            height: slot.running ? 4 : 0
                            color: Theme.accent
                            Behavior on height { SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.2 } }
                        }
                        MouseArea {
                            id: ima
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onContainsMouseChanged: {
                                if (containsMouse) {
                                    win.tipText = slot.modelData.name
                                    win.tipPos = slot.mapToItem(null, 0, slot.height / 2).y
                                    win.tipShown = true
                                } else if (win.tipText === slot.modelData.name) win.tipShown = false
                            }
                            onClicked: mouse => {
                                bounce.restart()
                                // left: jump to the running window, or start the app; middle: always a new window
                                if (slot.running && mouse.button !== Qt.MiddleButton) Niri.focusWindow(slot.win_.id)
                                else if (slot.modelData.entry) slot.modelData.entry.execute()
                            }
                        }
                    }
                }

                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 28; height: 1; color: Theme.line }

                // clipboard history flyout
                Rectangle {
                    id: clipBtn
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38; height: 38; radius: 12
                    color: Shell.overlay === "clipboard" ? Theme.accentSoft : (cma.containsMouse ? Theme.hover : Theme.tint)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    scale: cma.pressed ? 0.88 : (cma.containsMouse ? 1.14 : 1)
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 } }
                    Icon { anchors.centerIn: parent; text: ""; color: Shell.overlay === "clipboard" ? Theme.accent : Theme.fg }
                    MouseArea {
                        id: cma
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse) { win.tipText = "Clipboard"; win.tipPos = clipBtn.mapToItem(null, 0, clipBtn.height / 2).y; win.tipShown = true }
                            else if (win.tipText === "Clipboard") win.tipShown = false
                        }
                        onClicked: Shell.toggle("clipboard")
                    }
                }

                // tray
                Repeater {
                    model: SystemTray.items
                    delegate: Rectangle {
                        id: t
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 34; height: 34; radius: 11
                        color: tma.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        scale: tma.containsMouse ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 } }
                        Image { anchors.centerIn: parent; width: 20; height: 20; source: t.modelData.icon; sourceSize: Qt.size(40, 40) }
                        MouseArea {
                            id: tma
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            readonly property string label: t.modelData.tooltipTitle || t.modelData.title || ""
                            onContainsMouseChanged: {
                                if (containsMouse && label !== "") {
                                    win.tipText = label
                                    win.tipPos = t.mapToItem(null, 0, t.height / 2).y
                                    win.tipShown = true
                                } else if (win.tipText === label) win.tipShown = false
                            }
                            onWheel: w => { if (w.angleDelta.y !== 0) t.modelData.scroll(w.angleDelta.y, false) }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton || t.modelData.onlyMenu) {
                                    if (t.modelData.hasMenu) {
                                        const p = t.mapToItem(null, t.width, 0)
                                        t.modelData.display(win, p.x + 6, p.y)
                                    }
                                } else if (mouse.button === Qt.MiddleButton) t.modelData.secondaryActivate()
                                else t.modelData.activate()
                            }
                        }
                    }
                }
            }
        }
    }
}
