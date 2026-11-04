import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"

PanelWindow {
    id: win
    readonly property bool open: Shell.overlay === "launcher"

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || card.opacity > 0

    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Every result is { kind: "app"|"cmd"|"pkg", title, sub, icon?, data }
    property var results: []
    property string mode: "app"        // app | cmd | pkg
    property bool busy: false
    readonly property string terminal: "alacritty"

    // Prefixes:  ">cmd" run a command   |   "z name" search zypper packages
    function parse(text) {
        if (text.startsWith(">")) return { mode: "cmd", q: text.slice(1).trim() }
        const m = text.match(/^(z|zy|zypper)\s+(.*)$/i)
        if (m) return { mode: "pkg", q: m[2].trim() }
        return { mode: "app", q: text.trim() }
    }

    // Score: higher is better, 0 = no match.
    function score(app, q) {
        const name = app.name.toLowerCase()
        if (name === q) return 100
        if (name.startsWith(q)) return 80
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 65
        if (name.includes(q)) return 50
        const extra = ((app.genericName ?? "") + " " + (app.keywords ?? []).join(" ") + " " + (app.comment ?? "")).toLowerCase()
        if (extra.includes(q)) return 30
        let i = 0
        for (const c of name) if (c === q[i]) i++
        return i === q.length ? 15 : 0
    }

    function runRow(cmd) {
        return { kind: "cmd", title: cmd, sub: "Enter: run  \u00b7  Shift+Enter: run in terminal", data: cmd }
    }

    function setResults(list) { results = list; listView.currentIndex = 0 }

    function search(text) {
        const p = parse(text)
        mode = p.mode
        zyTimer.stop()
        if (p.mode === "cmd") {
            busy = false
            setResults(p.q ? [runRow(p.q)] : [])
        } else if (p.mode === "pkg") {
            if (p.q.length < 2) { busy = false; setResults([]); return }
            busy = true
            zyTimer.restart()
        } else {
            busy = false
            const q = p.q.toLowerCase()
            const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
            let out
            if (q === "") out = apps.slice().sort((x, y) => x.name.localeCompare(y.name))
            else out = apps.map(a => ({ a, s: score(a, q) })).filter(x => x.s > 0)
                           .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).map(x => x.a)
            const items = out.map(a => ({ kind: "app", title: a.name, sub: a.comment || a.genericName || "", icon: a.icon, data: a }))
            // Nothing matched? Offer to run it as a command.
            if (items.length === 0 && q !== "") items.push(runRow(p.q))
            setResults(items)
        }
    }

    // --- zypper search (debounced, async) ---
    property string pkgQuery: ""
    Timer {
        id: zyTimer
        interval: 220
        onTriggered: { win.pkgQuery = win.parse(input.text).q; zyProc.running = false; zyProc.running = true }
    }
    Process {
        id: zyProc
        command: ["zypper", "--quiet", "--no-refresh", "se", "--type", "package", "--", win.pkgQuery]
        stdout: StdioCollector {
            onStreamFinished: {
                if (win.mode !== "pkg" || win.parse(input.text).q !== win.pkgQuery) return
                const items = []
                for (const line of text.split("\n")) {
                    const c = line.split("|").map(x => x.trim())
                    if (c.length < 4 || c[1] === "Name" || c[0].startsWith("--")) continue
                    const st = line.split("|")[0].trim()
                    items.push({ kind: "pkg", title: c[1], sub: c[2], installed: st.startsWith("i") || st.startsWith("v"), data: c[1] })
                }
                items.sort((x, y) => (y.title === win.pkgQuery) - (x.title === win.pkgQuery) || x.title.length - y.title.length)
                win.busy = false
                win.setResults(items.slice(0, 60))
            }
        }
    }

    function inTerminal(script) {
        Quickshell.execDetached([terminal, "-e", "bash", "-c", script + "; echo; read -n1 -s -r -p 'Press any key to close…'"])
    }

    function activate(item, shift) {
        if (!item) return
        if (item.kind === "app") item.data.execute()
        else if (item.kind === "cmd") {
            if (shift) inTerminal(item.data)
            else Quickshell.execDetached(["sh", "-c", item.data])
        } else if (item.kind === "pkg") {
            const verb = item.installed ? "remove" : "install"
            inTerminal("sudo zypper " + verb + " " + item.data)
        }
        Shell.close()
    }

    onOpenChanged: if (open) { input.text = ""; search(""); input.forceActiveFocus() }

    // Dim backdrop, click to dismiss
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: Shell.close() }
    }

    Rectangle {
        id: card
        width: 460
        height: Math.min(42 + 8 + Math.max(listView.contentHeight, 4) + 16, 372)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.25 + (win.open ? 0 : -8)
        radius: Theme.radius + 4
        color: Theme.glass
        border { color: Qt.rgba(1, 1, 1, 0.07); width: 1 }
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.985
        clip: true

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on height  { NumberAnimation { duration: Theme.animFast;   easing.type: Theme.easing } }

        // Search field
        Rectangle {
            id: field
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
            height: 42
            radius: Theme.radius
            color: Qt.rgba(1, 1, 1, 0.05)

            Rectangle {
                id: chip
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                visible: opacity > 0
                opacity: win.mode !== "app" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                width: chipText.implicitWidth + 14; height: 22; radius: 11
                color: Qt.rgba(1, 1, 1, 0.08)
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: win.busy ? "…" : (win.mode === "pkg" ? "zypper" : "run")
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
            }

            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 16; rightMargin: chip.visible ? chip.width + 20 : 16 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                font { family: Theme.font; pixelSize: Theme.fontSize + 2 }
                clip: true
                onTextChanged: if (win.open) win.search(text)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { Shell.close(); event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        win.activate(win.results[listView.currentIndex], event.modifiers & Qt.ShiftModifier); event.accepted = true
                    }
                    else if (event.key === Qt.Key_Down || (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
                        listView.currentIndex = Math.min(listView.currentIndex + 1, win.results.length - 1); event.accepted = true
                    } else if (event.key === Qt.Key_Up || (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
                        listView.currentIndex = Math.max(listView.currentIndex - 1, 0); event.accepted = true
                    }
                }

                Text {
                    visible: !input.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search…"
                    color: Theme.fgDim
                    font: input.font
                }
            }
        }

        ListView {
            id: listView
            anchors { top: field.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
            model: win.results
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.animFast
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            // Sliding highlight
            Rectangle {
                parent: listView.contentItem
                z: 0
                width: listView.width
                height: 40
                radius: Theme.radiusSmall + 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                visible: listView.count > 0
                y: listView.currentIndex * 40
                Behavior on y { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: listView.width
                height: 40
                z: 1

                Item {
                    id: icon
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24
                    Image {
                        anchors.fill: parent
                        visible: row.modelData.kind === "app"
                        sourceSize: Qt.size(60, 60)
                        source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: row.modelData.kind !== "app"
                        radius: Theme.radiusSmall
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: row.modelData.kind === "pkg" ? "pkg" : ">_"
                            color: Theme.fgDim
                            font { family: "monospace"; pixelSize: 11; bold: true }
                        }
                    }
                }
                Column {
                    anchors { left: icon.right; leftMargin: 12; right: parent.right; rightMargin: row.modelData.kind === "pkg" ? 80 : 12; verticalCenter: parent.verticalCenter }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: row.modelData.title
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize }
                    }
                }
                Text {
                    visible: row.modelData.kind === "pkg" && row.modelData.installed
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: "installed"
                    color: Theme.ok
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: listView.currentIndex = row.index
                    onClicked: win.activate(row.modelData, false)
                }
            }
        }

        Text {
            visible: win.results.length === 0 && input.text !== "" && !win.busy && win.mode === "pkg" && win.parse(input.text).q.length >= 2
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
            text: "No packages found"
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize }
        }
    }
}
