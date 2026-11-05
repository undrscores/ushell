import Quickshell
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
        // replaced JS array rebuilds every delegate and the icons would re-pop.
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

        Connections {
            target: Niri
            function onWindowsChanged() { win.rebuildItems() }
        }
        Connections {
            target: Config
            function onPinnedAppsChanged() { win.rebuildItems() }     // config.json edited
        }
        Connections {
            target: DesktopEntries.applications
            function onValuesChanged() { win.rebuildItems() }   // entries finish loading after the first window event
        }
        Component.onCompleted: rebuildItems()

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
                            Behavior on scale { Spring { preset: "snap"; epsilon: 0.002 } }
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
                            Behavior on height { Spring { preset: "snap"; epsilon: 0.2 } }
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
            }
        }
    }
}
