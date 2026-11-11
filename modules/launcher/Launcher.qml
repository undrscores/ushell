import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"
import "../../components"
import "calc.js" as Calc
import "search.js" as Search
import "units.js" as Units
import "emoji.js" as EmojiData

// Launcher. Plain text searches apps, open windows, system actions and does maths.
// Prefixes switch mode:   z packages (pacman)   m music (MPD)   f files   g web   ? help
PanelWindow {
    id: win
    readonly property bool open: Shell.overlay === "launcher"

    screen: Quickshell.screens.find(s => s.name === Wm.focusedOutput) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || card.opacity > 0

    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Every result: { kind, title, tag?, icon?, glyph?, data, id?, installed?, danger?, score }
    //   kind: app | win | calc | action | pkg | song | file | web | emoji | clip | cmd | hint
    property var results: []
    property string mode: "app"        // app | pkg | song | file | web | emoji | clip | cmd | help
    property bool busy: false
    property bool gaveUp: false        // an async search never answered (tool missing, or too slow)
    property string asyncQuery: ""
    readonly property string home: Quickshell.env("HOME")

    // ── usage ranking (apps you launch often float up) ─────────────────────────
    property var usage: ({})
    readonly property string usagePath: StateDir.dir + "/launcher.json"
    FileView {
        id: usageFile
        path: StateDir.ready ? win.usagePath : ""
        watchChanges: false
        printErrors: false      // no file yet on a fresh install
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
        { kind: "hint", title: "yt gh w so maps   Search one site", glyph: "\uf002", data: "yt " },
        { kind: "hint", title: "e   Emoji picker",                glyph: "\uf118", data: "e " },
        { kind: "hint", title: "c   Search the clipboard history", glyph: "\uf0ea", data: "c " },
        { kind: "hint", title: ">   Run a shell command",         glyph: "\uf120", data: "> " },
        { kind: "hint", title: "5 km in mi   Convert units",      glyph: "\uf0ec", data: "" },
        { kind: "hint", title: "z   Install or remove packages", glyph: "", data: "z " },
        { kind: "hint", title: "m   Play music from MPD",         glyph: "", data: "m " },
        { kind: "hint", title: "f   Find files",                  glyph: "", data: "f " },
        { kind: "hint", title: "g   Search the web",              glyph: "", data: "g " },
        { kind: "hint", title: "2*(3+4)   Type a calculation",    glyph: "", data: "" }
    ]

    function setResults(list) { results = list; listView.currentIndex = 0 }

    // [{ ch, name }] from emoji.js, parsed on first use
    property var emojiList: []
    function emojis() {
        if (emojiList.length === 0)
            emojiList = EmojiData.RAW.split("\n").map(l => { const i = l.indexOf("|"); return { ch: l.slice(0, i), name: l.slice(i + 1) } })
        return emojiList
    }
    property bool emojiFont: true           // a colour emoji font is installed (without one the picker still copies, but shows boxes)
    Process {
        id: emojiProbe
        command: ["sh", "-c", "fc-list :color=true family | head -1"]
        stdout: StdioCollector { onStreamFinished: { win.emojiFont = text.trim() !== ""; if (win.mode === "emoji") win.search(input.text) } }
    }
    function emojiResults(q) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w !== "")
        const out = []
        for (const e of emojis()) {
            let s = 1
            for (const w of words) {
                const t = Search.textScore(e.name, w)
                if (t <= 0) { s = 0; break }
                s += t
            }
            if (s > 0) out.push({ kind: "emoji", title: e.ch + "   " + e.name.split(" ").slice(0, 4).join(" "), data: e.ch, id: "emoji:" + e.ch, tag: "copy", score: s - e.name.length * 0.05 + bonus("emoji:" + e.ch) * 4 })
        }
        out.sort((a, b) => b.score - a.score)
        const list = out.slice(0, 60)
        if (!emojiFont) list.push({ kind: "hint", title: "No colour emoji font found (google-noto-coloremoji-fonts)", glyph: "\uf071", data: "" })
        return list
    }
    function clipResults(q) {
        const ql = q.toLowerCase()
        const out = []
        for (const it of Clipboard.items) {
            const text = it.text || (it.type === "image" ? "image" : "")
            if (ql !== "" && !text.toLowerCase().includes(ql)) continue
            const line = text.split("\n").find(l => l.trim() !== "") ?? ""
            out.push({ kind: "clip", title: line.trim().slice(0, 120) || "(empty)", tag: it.type === "image" ? "image" : (it.pinned ? "pinned" : ""),
                       glyph: it.type === "image" ? "\uf03e" : "\uf0ea", data: it })
            if (out.length >= 60) break
        }
        return out
    }

    function buildDefault(q) {
        const ql = q.toLowerCase()
        const out = []

        const u = ql ? Units.tryConvert(q) : null
        if (u !== null) out.push({ kind: "calc", title: u.text, tag: "copy", glyph: "\uf0ec", data: u.value, score: 1000 })
        const c = ql ? Calc.tryCalc(q) : null
        if (c !== null) out.push({ kind: "calc", title: "= " + c, tag: "copy", glyph: "", data: c, score: 1000 })

        Wm.windows.forEach((w, i) => {
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
        return out.slice(0, 60)
    }

    // what the empty-query list is built from; lets a window event that changed nothing visible be ignored
    property string winSig: ""
    function windowSig() { return Wm.windows.map(w => w.id + "\t" + (w.title || w.app_id || "")).join("\n") }

    function search(text) {
        winSig = windowSig()
        const p = Search.parse(text, Config.searchShortcuts)
        mode = p.mode
        Actions.disarm()
        asyncTimer.stop()
        giveUp.stop()
        busy = false
        gaveUp = false

        if (p.mode === "help") setResults(helpRows)
        else if (p.mode === "web")
            setResults(p.q ? [{ kind: "web", title: "Search the web for “" + p.q + "”", tag: p.url ? (p.url.split("/")[2] ?? "web").replace(/^(www|en)\./, "") : "web", glyph: "", data: p.q, url: p.url }] : [])
        else if (p.mode === "emoji") { if (!emojiProbe.running && emojiList.length === 0) emojiProbe.running = true; setResults(emojiResults(p.q)) }
        else if (p.mode === "clip") setResults(clipResults(p.q))
        else if (p.mode === "cmd")
            setResults(p.q ? [{ kind: "cmd", title: "Run  " + p.q, tag: "shift: in a terminal", glyph: "\uf120", data: p.q }]
                           : [{ kind: "hint", title: "Type a command, Enter runs it (Shift+Enter: in a terminal)", glyph: "\uf120", data: "" }])
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
            const p = Search.parse(input.text, Config.searchShortcuts)
            win.asyncQuery = p.q
            giveUp.restart()
            if (p.mode === "pkg")  { pkgProc.running = false;  pkgProc.running = true }
            if (p.mode === "song") { songProc.running = false; songProc.running = true }
            if (p.mode === "file") { fileProc.running = false; fileProc.running = true }
        }
    }
    // A program that is not installed never reports back; stop showing "…" and say so.
    Timer { id: giveUp; interval: 6000; onTriggered: if (win.busy) { win.busy = false; win.gaveUp = true } }
    function stale(expect) { const p = Search.parse(input.text, Config.searchShortcuts); return mode !== expect || p.q !== asyncQuery }

    Process {
        id: pkgProc
        command: ["pacman", "-Ss", "--", win.asyncQuery.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")]   // the query is a regex: match it literally
        stdout: StdioCollector {
            onStreamFinished: {
                if (win.stale("pkg")) return
                // pacman -Ss prints "repo/name version [installed]" followed by an indented description line (skipped)
                const items = []
                for (const line of text.split("\n")) {
                    if (line.startsWith(" ") || line.trim() === "") continue
                    const m = line.match(/^[^\/\s]+\/(\S+)\s+\S+(.*)$/)
                    if (!m) continue
                    items.push({ kind: "pkg", title: m[1], glyph: "", installed: m[2].includes("[installed"), data: m[1] })
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
        command: ["timeout", "3", "fd", "--type", "f", "--max-results", "40", "--max-depth", "8", "--ignore-case", "--fixed-strings", "--", win.asyncQuery, win.home]
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
    // (The "cmd" mode below is the exception: what you type after ">" is deliberately run as a shell command line.)
    function inTerminal(args) {
        Quickshell.execDetached([Config.terminal, "-e", "bash", "-c",
            "sudo \"$@\"; echo; read -n1 -s -r -p 'Press any key to close…'", "ushell"].concat(args))
    }

    function activate(item, alt) {
        if (!item) return
        if (item.kind === "hint" && item.data === "") return
        if (item.kind === "hint") {
            input.text = item.data
            input.cursorPosition = input.text.length
            return
        }
        switch (item.kind) {
        case "app": {
            bump(item.id)
            const w = Wm.appWindow(item.data)       // already running? jump to it instead of a second copy
            if (w) Wm.focusWindow(w.id); else item.data.execute()
            break
        }
        case "win":    Wm.focusWindow(item.data); break
        case "calc":   Quickshell.execDetached(["wl-copy", item.data]); break
        case "action": if (!Actions.trigger(item.data)) return; bump(item.id); break
        case "pkg":    inTerminal(["pacman", item.installed ? "-Rs" : "-S", "--", item.data]); break
        case "song":   Quickshell.execDetached(["python3", "-I", Mpd.script, alt ? "queue" : "playuri", item.data]); break
        case "file": {
            const target = alt ? item.data.slice(0, item.data.lastIndexOf("/")) : item.data
            Quickshell.execDetached(["xdg-open", target]); break
        }
        case "web":    Quickshell.execDetached(["xdg-open", (item.url || Config.searchUrl) + encodeURIComponent(item.data)]); break
        case "emoji":
            bump(item.id)
            Quickshell.execDetached(["wl-copy", item.data])
            Osd.showText("note", "Copied " + item.data, true, "\uf0c5")
            break
        case "clip":   Clipboard.copy(item.data.id); Osd.showText("note", "Copied from history", true, "\uf0c5"); break
        case "cmd":
            if (alt) Quickshell.execDetached([Config.terminal, "-e", "sh", "-c", item.data + "; echo; read -n1 -s -r -p 'Press any key to close…'"])
            else Quickshell.execDetached(["sh", "-c", item.data])
            break
        }
        if (Shell.overlay === "launcher") Shell.close()   // actions may have opened something else
    }

    // used by `qs ipc call launcher query "m "` (see shell.qml): open with that text typed in
    function query(text) { Shell.open("launcher"); input.text = text }

    property bool fresh: false
    Timer { id: freshTimer; interval: 450; onTriggered: win.fresh = false }
    onOpenChanged: if (open) { fresh = true; freshTimer.restart(); Wm.refresh(); input.text = ""; search(""); input.forceActiveFocus() }
    Connections {
        target: Wm
        function onWindowsChanged() { if (win.open && input.text === "" && win.windowSig() !== win.winSig) win.search("") }
    }

    readonly property string emptyText: {
        if (results.length > 0 || busy) return ""
        if (gaveUp) return "Search failed or timed out"
        const q = Search.parse(input.text, Config.searchShortcuts).q
        if (mode === "pkg"  && q.length >= 2) return "No packages found"
        if (mode === "song" && q.length >= 1) return "No songs found"
        if (mode === "file" && q.length >= 2) return "No files found"
        return ""
    }

    // click outside to dismiss
    Rectangle {
        anchors.fill: parent
        color: Theme.scrimColor
        opacity: win.open ? 0.3 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }
        MouseArea { anchors.fill: parent; onClicked: Shell.close() }
    }

    Rectangle {
        id: card
        width: 480
        height: Math.min(42 + 8 + Math.max(listView.contentHeight, win.emptyText !== "" ? 46 : 4) + 16, 372)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.25 + (win.open ? 0 : -8)
        radius: Theme.radiusLarge
        color: Theme.glass
        border { color: Theme.line; width: 1 }
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.84
        clip: true

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale   { Spring { preset: win.open ? "popIn" : "popOut"; epsilon: 0.002 } }
        Behavior on y       { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on height  { Spring { preset: "glide"; epsilon: 0.4 } }

        // Search field
        Rectangle {
            id: field
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
            height: 42
            radius: Theme.radius
            color: Theme.tint

            Rectangle {
                id: chip
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                visible: opacity > 0
                opacity: win.mode !== "app" ? 1 : 0
                scale: win.mode !== "app" ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on scale   { Pop { duration: Theme.animSlow; overshoot: 3 } }
                width: chipText.implicitWidth + 16; height: 22; radius: 11
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: win.busy ? "…" : ({ pkg: "pacman", song: "music", file: "files", web: "web", emoji: "emoji", clip: "clipboard", cmd: "run", help: "modes" }[win.mode] ?? "")
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
                    } else if (event.key === Qt.Key_PageDown) {
                        listView.currentIndex = Math.min(listView.currentIndex + 6, win.results.length - 1); event.accepted = true
                    } else if (event.key === Qt.Key_PageUp) {
                        listView.currentIndex = Math.max(listView.currentIndex - 6, 0); event.accepted = true
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
                Behavior on y { Spring { preset: "snap" } }
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
