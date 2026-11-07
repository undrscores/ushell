pragma Singleton
import Quickshell
import QtQuick
import "../modules/launcher/search.js" as Search

// The window switcher (modules/switcher): every open window, most recently used first, filtered by what is typed.
//
//   qs ipc call switcher next      Alt+Tab: opens on the previous window; again to go on; letting go of the modifier picks it
//   qs ipc call switcher prev      Alt+Shift+Tab
//   qs ipc call switcher toggle    open for searching (type to filter, Enter to pick)
Singleton {
    id: root

    readonly property bool open: Shell.overlay === "switcher"
    property string query: ""
    property int index: 0
    property bool cycle: false               // opened by next / prev: releasing the modifier key picks the window
    property int startDir: 1

    function stamp(w) { const t = w.focus_timestamp; return t ? t.secs * 1e9 + t.nanos : 0 }
    function workspaceOf(w) { return Wm.workspaces.find(x => x.id === w.workspace_id) ?? null }

    // { id, title, app, icon, where, focused, urgent }
    readonly property var entries: {
        const q = query.trim().toLowerCase()
        const multi = new Set(Wm.workspaces.map(x => x.output)).size > 1
        const out = []
        for (const w of Wm.windows) {
            const title = w.title || w.app_id || "Window"
            const app = w.app_id || ""
            let score = stamp(w)
            if (q !== "") {
                const s = Math.max(Search.textScore(title.toLowerCase(), q), Search.textScore(app.toLowerCase(), q))
                if (s <= 0) continue
                score = s * 1e15 + score / 1e6        // best match first, recent use breaks ties
            }
            const ws = workspaceOf(w)
            const entry = app ? DesktopEntries.heuristicLookup(app) : null
            let where = ws ? (ws.name || "Workspace " + ws.idx) : ""
            if (ws && multi) where += " · " + ws.output
            if (w.is_floating) where += where ? " · floating" : "floating"
            out.push({ id: w.id, title: title, app: entry && entry.name ? entry.name : app, icon: entry ? entry.icon : "",
                       where: where, focused: w.is_focused === true, urgent: w.is_urgent === true, score: score })
        }
        out.sort((a, b) => b.score - a.score)
        return out
    }

    onOpenChanged: {
        if (open) {
            query = ""
            Wm.refresh()
            index = cycle && entries.length > 1 ? (startDir > 0 ? 1 : entries.length - 1) : 0
        } else cycle = false
    }
    onQueryChanged: index = 0

    function step(dir) {
        const n = entries.length
        if (n > 0) index = (index + dir + n) % n
    }
    function press(dir) {
        if (!open) { cycle = true; startDir = dir; Shell.open("switcher") }
        else step(dir)
    }
    function toggle() {
        if (open) Shell.close()
        else { cycle = false; Shell.open("switcher") }
    }
    function pick(i) {
        const e = entries[i]
        Shell.close()
        if (e) Wm.focusWindow(e.id)
    }
    function closeWindow(i) {
        const e = entries[i]
        if (e) Wm.closeWindow(e.id)
    }
}
