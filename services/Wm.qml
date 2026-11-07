pragma Singleton
import Quickshell
import QtQuick

// The compositor as the rest of the shell sees it: workspaces, windows, the focused output and the
// commands on them, all derived from uwm's IPC snapshot (services/Uwm.qml). uwm's "workspaces" are the
// tags of each monitor, so a workspace id is "<output>:<tag>" and idx is the 1-based tag.
Singleton {
    id: root
    readonly property var snap: Uwm.state
    readonly property string focusedOutput: snap.selmon ?? ""
    readonly property var layouts: []              // uwm does not expose keyboard layouts yet
    readonly property string layoutName: ""
    readonly property string layoutShort: ""

    function firstTag(mask) {
        for (let i = 0; i < 9; i++) if (mask & (1 << i)) return i + 1
        return 1
    }

    // Tags of the focused monitor that are in use or shown (the dots in the bar), in tag order.
    readonly property var workspaces: {
        const out = []
        for (const m of snap.monitors ?? []) {
            if (m.name !== focusedOutput) continue
            for (const t of m.tags)
                if (t.active || t.occupied)
                    out.push({ id: m.name + ":" + t.n, idx: t.n, name: "", output: m.name,
                               is_active: t.active, is_focused: t.active && m.focused,
                               is_urgent: t.urgent, active_window_id: t.occupied ? 1 : null })
        }
        return out
    }

    // Windows in niri's shape (id, title, app_id, workspace_id, is_*) plus focus_timestamp, which is a
    // counter of focus changes made here since the shell started (the switcher sorts on it).
    property var focusSeq: ({})
    property int seqNow: 0
    readonly property var windows: (snap.windows ?? []).map(w => ({
        id: w.id, title: w.title, app_id: w.app_id, workspace_id: w.monitor + ":" + firstTag(w.tags),
        output: w.monitor, is_floating: w.floating, is_focused: w.focused, is_urgent: w.urgent,
        focus_timestamp: { secs: focusSeq[w.id] ?? 0, nanos: 0 } }))

    property int lastFocused: -1
    onSnapChanged: {
        const f = (snap.windows ?? []).find(w => w.focused)
        if (!f || f.id === lastFocused) return
        lastFocused = f.id
        seqNow++
        const m = Object.assign({}, focusSeq)
        m[f.id] = seqNow
        focusSeq = m
    }

    // First open window belonging to a desktop entry (matched on app_id), or null.
    function appWindow(entry) {
        if (!entry) return null
        const ids = [entry.id, entry.startupClass, entry.name].filter(x => x).map(x => x.toLowerCase())
        return windows.find(w => w.app_id && ids.includes(w.app_id.toLowerCase())) ?? null
    }

    // Screen rectangle "x,y WxH" of the focused window, for grim; null when none is focused.
    function focusedWindowGeometry() {
        const w = (snap.windows ?? []).find(x => x.focused)
        if (!w) return null
        const m = (snap.monitors ?? []).find(x => x.name === w.monitor)
        if (!m) return null
        const z = m.viewport.zoom, r = Math.round
        return r((w.x - m.viewport.x) * z + m.x) + "," + r((w.y - m.viewport.y) * z + m.y) + " " + r(w.width * z) + "x" + r(w.height * z)
    }
    function focusWindow(id) { Uwm.send("focus " + id) }
    function closeWindow(id) { Uwm.send("close " + id) }
    function focusWorkspace(idx) { Uwm.send("view " + idx) }
    function stepWorkspace(dir) {                  // dir > 0: next tag in use, < 0: previous
        const list = workspaces
        const cur = list.findIndex(w => w.is_active)
        const next = list[cur + (dir > 0 ? 1 : -1)]
        if (next) focusWorkspace(next.idx)
    }
    function switchLayout(dir) {}
    function refresh() {}                          // the snapshot is pushed on every change
    function logout() { Uwm.send("quit") }
    function screensOff(off) { Uwm.send("dpms " + (off ? "off" : "on")) }
}
