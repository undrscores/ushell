import Quickshell
import QtQuick
import "../../config"
import "../../services"
import "dock.js" as DockOrder
import "../../components"

// macOS-style dock on the left edge of each screen. Auto-hidden: only a thin strip at the
// very edge is live, and hovering it pops the dock out (EdgePanel's bouncy spring). Icons
// magnify as the cursor nears them and the app name shows beside them.
//
// Contents: the pinned apps (Prefs.dockApps), a separator, then the apps with windows on
// THIS screen ("active" here, most recently focused first), a separator, and a launcher
// button. A running app gets an accent dot (plus a count badge when it has several windows).
// Click focuses the app's most recent window on this screen (or launches it); right-click
// pins / unpins the app.
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "left"
        autoHide: true
        panelWidth: 72
        panelHeight: col.implicitHeight + 20
        panelRadius: Theme.radiusLarge
        readonly property string screenName: screen ? screen.name : ""

        // pinned apps (Prefs.dockApps holds desktop entry ids)
        readonly property var pinned: {
            const out = []
            for (const id of Prefs.dockApps) {
                const e = DesktopEntries.byId(id)
                if (e && !e.noDisplay) out.push(e)
            }
            return out
        }
        // apps with at least one window on this screen, most recently focused first
        readonly property var running: {
            const wins = Wm.windows
                .filter(w => w.output === win.screenName && w.app_id)
                .sort((a, b) => (b.focus_timestamp.secs - a.focus_timestamp.secs))
            const out = []
            const seen = {}
            for (const w of wins) {
                const e = DesktopEntries.heuristicLookup(w.app_id)
                if (e && !seen[e.id]) { seen[e.id] = true; out.push(e) }
            }
            return out
        }

        // all windows of a desktop entry (matched like Wm.appWindow does), any screen
        function windowsFor(e) {
            const ids = [e.id, e.startupClass, e.name].filter(x => x).map(x => x.toLowerCase())
            return Wm.windows.filter(w => w.app_id && ids.includes(w.app_id.toLowerCase()))
        }
        function isRunning(e) { return windowsFor(e).length > 0 }
        function winCount(e) { return windowsFor(e).length }
        function isPinned(e) { return Prefs.dockApps.includes(e.id) }
        function togglePin(e) {
            const rest = Prefs.dockApps.filter(x => x !== e.id)
            Prefs.set("dockApps", isPinned(e) ? rest : rest.concat([e.id]))
        }
        // an icon dropped at height y (column coordinates) onto another pinned one takes its place
        function dropPin(e, y) {
            if (!isPinned(e)) return
            for (let i = 0; i < pinRep.count; i++) {
                const item = pinRep.itemAt(i)
                if (item && y >= item.y && y < item.y + item.height) {
                    Prefs.set("dockApps", DockOrder.reorder(Prefs.dockApps, e.id, pinned[i].id))
                    return
                }
            }
        }
        function activate(e) {
            const wins = windowsFor(e)
            if (wins.length === 0) { e.execute(); return }
            const here = wins.filter(w => w.output === win.screenName)
            const pool = here.length > 0 ? here : wins
            pool.sort((a, b) => (b.focus_timestamp.secs - a.focus_timestamp.secs))
            Wm.focusWindow(pool[0].id)
        }

        // Cursor position along the dock, in column coordinates (-1e9 = far away: no magnification).
        // Uses the slot's resting centre (y + 21), never the animated height, so nothing loops.
        property real mouseY: -1e9
        onShownChanged: if (!shown) mouseY = -1e9
        HoverHandler { onHoveredChanged: if (!hovered) win.mouseY = -1e9 }

        // one icon for both the pinned and the running section
        Component {
            id: iconDelegate
            Item {
                id: dlg
                required property var modelData
                readonly property var entry: modelData
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56
                readonly property real cy: y + 21
                readonly property real mag: Math.exp(-((cy - win.mouseY) * (cy - win.mouseY)) / (2 * 62 * 62))
                height: 42 + 26 * mag
                Behavior on height { Spring { preset: "snap"; epsilon: 0.05 } }

                Item {
                    id: iconBox
                    anchors.centerIn: parent
                    readonly property real s: dlg.height - 8
                    width: s; height: s
                    readonly property string iconSrc: (dlg.entry.icon ?? "") !== "" ? Quickshell.iconPath(dlg.entry.icon, true) : ""
                    Image {
                        anchors.fill: parent
                        visible: iconBox.iconSrc !== ""
                        source: iconBox.iconSrc
                        sourceSize: Qt.size(96, 96)
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: iconBox.iconSrc === ""
                        radius: Theme.radiusSmall + 2
                        color: Theme.hover
                        Icon { anchors.centerIn: parent; text: "\uf2d0"; size: iconBox.s * 0.5; color: Theme.fgDim }
                    }
                }

                // running indicator
                Rectangle {
                    visible: win.isRunning(dlg.entry)
                    width: 5; height: 5; radius: 2.5
                    color: Theme.accent
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                }
                // window count badge (apps with more than one window)
                Rectangle {
                    visible: win.winCount(dlg.entry) > 1
                    anchors { right: iconBox.right; bottom: iconBox.bottom }
                    width: countLabel.implicitWidth + 8; height: 16; radius: 8
                    color: Theme.accent
                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: win.winCount(dlg.entry)
                        color: Theme.accentFg
                        font { family: Theme.font; pixelSize: 10; bold: true }
                    }
                }

                MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton     // right click pins / unpins (the default is left only)
                    cursorShape: Qt.PointingHandCursor
                    property real pressY: 0
                    property bool dragged: false                         // a pinned icon pulled along the dock: reorder, not click
                    onPressed: mouse => { pressY = mouse.y; dragged = false }
                    onReleased: mouse => { if (dragged && mouse.button === Qt.LeftButton) win.dropPin(dlg.entry, dlg.y + mouse.y) }
                    onPositionChanged: mouse => {
                        if (pressed && Math.abs(mouse.y - pressY) > 12) dragged = true
                        win.mouseY = dlg.y + mouse.y
                        win.tipText = dlg.entry.name + (win.winCount(dlg.entry) > 1 ? "  (" + win.winCount(dlg.entry) + " windows)" : "")
                        win.tipPos = (win.height - win.animH) / 2 + col.y + dlg.y + dlg.height / 2
                        win.tipShown = true
                    }
                    onExited: win.tipShown = false
                    onClicked: mouse => {
                        if (dragged) return
                        if (mouse.button === Qt.RightButton) win.togglePin(dlg.entry)
                        else win.activate(dlg.entry)
                    }
                }
            }
        }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: 4

            Repeater { id: pinRep; model: win.pinned; delegate: iconDelegate }

            Rectangle {   // separator between pinned and active apps
                visible: win.running.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: 26; height: 1; color: Theme.line
            }

            Repeater { model: win.running; delegate: iconDelegate }

            Rectangle {   // separator before the launcher button
                anchors.horizontalCenter: parent.horizontalCenter
                width: 26; height: 1; color: Theme.line
            }

            Item {   // show-apps button: opens the launcher
                id: appsBtn
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56
                readonly property real cy: y + 21
                readonly property real mag: Math.exp(-((cy - win.mouseY) * (cy - win.mouseY)) / (2 * 62 * 62))
                height: 42 + 26 * mag
                Behavior on height { Spring { preset: "snap"; epsilon: 0.05 } }
                Rectangle {
                    id: appsIcon
                    anchors.centerIn: parent
                    readonly property real s: appsBtn.height - 8
                    width: s; height: s
                    radius: Theme.radiusSmall + 2
                    color: Theme.hover
                    Icon { anchors.centerIn: parent; text: "\uf009"; size: appsIcon.s * 0.5; color: Theme.fg }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: mouse => {
                        win.mouseY = appsBtn.y + mouse.y
                        win.tipText = "Applications"
                        win.tipPos = (win.height - win.animH) / 2 + col.y + appsBtn.y + appsBtn.height / 2
                        win.tipShown = true
                    }
                    onExited: win.tipShown = false
                    onClicked: Shell.toggle("launcher")
                }
            }
        }
    }
}
