import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"
import "../../components"
import "calc.js" as Calc
import "search.js" as Search

// Launcher. Plain text searches apps, open windows, system actions and does maths.
// Prefixes switch mode:   z packages (zypper)   m music (MPD)   f files   g web   ? help
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

    // Every result: { kind, title, tag?, icon?, glyph?, data, id?, installed?, danger?, score }
    //   kind: app | win | calc | action | pkg | song | file | web | hint
    property var results: []
    property string mode: "app"        // app | pkg | song | file | web | help
    property bool busy: false
    property string asyncQuery: ""
    readonly property string home: Quickshell.env("HOME")

    // ── usage ranking (apps you launch often float up) ─────────────────────────
    property var usage: ({})
    readonly property string usagePath: StateDir.dir + "/launcher.json"
    FileView {
        id: usageFile
        path: StateDir.ready ? win.usagePath : ""
        watchChanges: false
        onLoaded: { try { win.usage = JSON.parse(usageFile.text()) } catch (e) {} }
    }
    function bonus(id) { return Math.min(25, Math.log2((usage[id] || 0) + 1) * 7) }
    function bump(id) {
        const u = Object.assign({}, usage)
        u[id] = (u[id] || 0) + 1
        usage = u
        if (StateDir.ready) usageFile.setText(JSON.stringify(u))
    }

    readonly property var helpRows: [
        { kind: "hint", title: "z   Install or remove packages", glyph: "", data: "z " },
        { kind: "hint", title: "m   Play music from MPD",         glyph: "", data: "m " },
        { kind: "hint", title: "f   Find files",                  glyph: "", data: "f " },
        { kind: "hint", title: "g   Search the web",              glyph: "", data: "g " },
        { kind: "hint", title: "2*(3+4)   Type a calculation",    glyph: "", data: "" }
    ]

    function setResults(list) { results = list; listView.currentIndex = 0 }

    function buildDefault(q) {
        const ql = q.toLowerCase()
        const out = []

        const c = ql ? Calc.tryCalc(q) : null
        if (c !== null) out.push({ kind: "calc", title: "= " + c, tag: "copy", glyph: "", data: c, score: 1000 })

        Niri.windows.forEach((w, i) => {
            const title = w.title || w.app_id || "Window"
            let s
            if (ql === "") s = 500 - i
            else {
                s = Math.max(Search.textScore(title.toLowerCase(), ql), Search.textScore((w.app_id || "").toLowerCase(), ql))
                if (s > 0) s = s * 0.9 + 5
            }
            if (s <= 0) return
            const entry = DesktopEntries.heuristicLookup(w.app_id)
            out.push({ kind: "win", title: title, tag: "window", icon: entry ? entry.icon : "", glyph: "", data: w.id, score: s })
        })

        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue
            const s = ql === "" ? 0 : Search.appScore(a, ql)
            if (ql !== "" && s <= 0) continue
            out.push({ kind: "app", title: a.name, icon: a.icon, data: a, id: "app:" + a.id, score: s + bonus("app:" + a.id) })
        }

        if (ql !== "") for (const d of Actions.defs) {
            const s = Math.max(Search.textScore(d.title.toLowerCase(), ql), d.words.includes(ql) ? 40 : 0)
            if (s > 0) out.push({ kind: "action", title: d.title, tag: "action", glyph: d.glyph, data: d, id: d.id, danger: d.danger === true, score: s * 0.95 + bonus(d.id) })
        }

        out.sort((x, y) => y.score - x.score || x.title.localeCompare(y.title))
        const top = out.slice(0, 60)
        if (top.length === 0 && ql !== "")
            top.push({ kind: "web", title: "Search the web for “" + q + "”", tag: "web", glyph: "", data: q, score: 0 })
        return top
    }

    function search(text) {
        const p = Search.parse(text)
        mode = p.mode
        Actions.disarm()
        asyncTimer.stop()
        busy = false

        if (p.mode === "help") setResults(helpRows)
        else if (p.mode === "web")
            setResults(p.q ? [{ kind: "web", title: "Search the web for “" + p.q + "”", tag: "web", glyph: "", data: p.q }] : [])
        else if (p.mode === "app") setResults(buildDefault(p.q))
        else {   // pkg | song | file: debounced, async
            const min = p.mode === "song" ? 1 : 2
            if (p.q.length < min) { setResults([]); return }
            busy = true
            asyncTimer.restart()
        }
    }

    // ── async sources ──────────────────────────────────────────────────────────
    Timer {
        id: asyncTimer
        interval: 220
        onTriggered: {
            const p = win.parse(input.text)
            win.asyncQuery = p.q
            if (p.mode === "pkg")  { pkgProc.running = false;  pkgProc.running = true }
            if (p.mode === "song") { songProc.running = false; songProc.running = true }
            if (p.mode === "file") { fileProc.running = false; fileProc.running = true }
        }
    }
    function stale(expect) { const p = Search.parse(input.text); return mode !== expect || p.q !== asyncQuery }

    Process {
        id: pkgProc
        command: ["zypper", "--quiet", "--no-refresh", "se", "--type", "package", "--", win.asyncQuery]
        stdout: StdioCollector {
            onStreamFinished: {
                if (win.stale("pkg")) return
                const items = []
                for (const line of text.split("\n")) {
                    const c = line.split("|").map(x => x.trim())
                    if (c.length < 4 || c[1] === "Name" || c[0].startsWith("--")) continue
                    const st = line.split("|")[0].trim()
                    items.push({ kind: "pkg", title: c[1], glyph: "", installed: st.startsWith("i") || st.startsWith("v"), data: c[1] })
                }
                items.sort((x, y) => (y.title === win.asyncQuery) - (x.title === win.asyncQuery) || x.title.length - y.title.length)
                win.busy = false
                win.setResults(items.slice(0, 60))
            }
        }
    }
    Process {
        id: songProc
        command: ["python3", "-I", Mpd.script, "search", win.asyncQuery]
        stdout: StdioCollector {
            onStreamFinished: {
                if (win.stale("song")) return
                let songs = []
                try { songs = JSON.parse(text) } catch (e) {}
                win.busy = false
                win.setResults(songs.map(s => ({
                    kind: "song", title: s.artist ? s.title + " — " + s.artist : s.title,
                    tag: s.album, glyph: "", data: s.uri
                })))
            }
        }
    }
    Process {
        id: fileProc
        command: ["timeout", "3", "fd", "--type", "f", "--max-results", "40", "--max-depth", "8", "--ignore-case", "--", win.asyncQuery, win.home]
        stdout: StdioCollector {
            onStreamFinished: {
                if (win.stale("file")) return
                win.busy = false
                win.setResults(text.split("\n").filter(l => l !== "").map(path => {
                    const i = path.lastIndexOf("/")
                    return { kind: "file", title: path.slice(i + 1), tag: path.slice(0, i).replace(win.home, "~"), glyph: "", data: path }
                }))
            }
        }
    }

    // ── activation ─────────────────────────────────────────────────────────────
    // Runs `sudo <args>` in a terminal and waits for a key. Arguments are passed as argv, never spliced into a shell string.
    function inTerminal(args) {
        Quickshell.execDetached([Config.terminal, "-e", "bash", "-c",
            "sudo \"$@\"; echo; read -n1 -s -r -p 'Press any key to close…'", "ushell"].concat(args))
    }

    function activate(item, alt) {
        if (!item) return
        if (item.kind === "hint") {
            input.text = item.data
            input.cursorPosition = input.text.length
            return
        }
        switch (item.kind) {
        case "app": {
            bump(item.id)
            const w = Niri.appWindow(item.data)       // already running? jump to it instead of a second copy
            if (w) Niri.focusWindow(w.id); else item.data.execute()
            break
        }
        case "win":    Niri.focusWindow(item.data); break
        case "calc":   Quickshell.execDetached(["wl-copy", item.data]); break
        case "action": if (!Actions.trigger(item.data)) return; bump(item.id); break
        case "pkg":    inTerminal(["zypper", item.installed ? "remove" : "install", item.data]); break
        case "song":   Quickshell.execDetached(["python3", "-I", Mpd.script, alt ? "queue" : "playuri", item.data]); break
        case "file": {
            const target = alt ? item.data.slice(0, item.data.lastIndexOf("/")) : item.data
            Quickshell.execDetached(["xdg-open", target]); break
        }
        case "web":    Quickshell.execDetached(["xdg-open", Config.searchUrl + encodeURIComponent(item.data)]); break
        }
        if (Shell.overlay === "launcher") Shell.close()   // actions may have opened something else
    }

    // used by `qs ipc call launcher query "m "` (see shell.qml): open with that text typed in
    function query(text) { Shell.open("launcher"); input.text = text }

    property bool fresh: false
    Timer { id: freshTimer; interval: 450; onTriggered: win.fresh = false }
    onOpenChanged: if (open) { fresh = true; freshTimer.restart(); Niri.refresh(); input.text = ""; search(""); input.forceActiveFocus() }
    Connections {
        target: Niri
        function onWindowsChanged() { if (win.open && input.text === "") win.search("") }
    }

    readonly property string emptyText: {
        if (results.length > 0 || busy) return ""
        const q = Search.parse(input.text).q
        if (mode === "pkg"  && q.length >= 2) return "No packages found"
        if (mode === "song" && q.length >= 1) return "No songs found"
        if (mode === "file" && q.length >= 2) return "No files found"
        return ""
    }

    // click outside to dismiss
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: Shell.close() }
    }

    Rectangle {
        id: card
        width: 480
        height: Math.min(42 + 8 + Math.max(listView.contentHeight, win.emptyText !== "" ? 46 : 4) + 16, 372)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.25 + (win.open ? 0 : -8)
        radius: Theme.radius + 4
        color: Theme.glass
        border { color: Qt.rgba(1, 1, 1, 0.07); width: 1 }
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.84
        clip: true

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { SpringAnimation { spring: win.open ? 3.6 : 6; damping: win.open ? 0.24 : 0.8; epsilon: 0.002 } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on height  { SpringAnimation { spring: 4.5; damping: 0.4; epsilon: 0.4 } }

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
                scale: win.mode !== "app" ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on scale   { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                width: chipText.implicitWidth + 16; height: 22; radius: 11
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: win.busy ? "…" : ({ pkg: "zypper", song: "music", file: "files", web: "web", help: "modes" }[win.mode] ?? "")
                    color: Theme.accent
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
                Behavior on y { SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.3 } }
            }

            delegate: LauncherRow {
                id: lr
                width: listView.width
                fresh: win.fresh
                armed: Actions.armed
                onHovered: listView.currentIndex = lr.index
                onActivated: win.activate(lr.modelData, false)
            }
        }

        Text {
            visible: win.emptyText !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
            text: win.emptyText
            color: Theme.fgDim
            font { family: Theme.font; pixelSize: Theme.fontSize }
        }
    }
}
