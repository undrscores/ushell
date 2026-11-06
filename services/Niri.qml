pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Thin wrapper over `niri msg`. Re-queries only what a niri event can have changed (debounced),
// ignores events that don't affect anything shown (layout shuffles, overview, keyboard layout, ...),
// and applies simple window changes (title edits, closes) straight from the event.
Singleton {
    id: root
    property var workspaces: []
    property string focusedOutput: ""
    property var windows: []
    property var layouts: []                // keyboard layout names, e.g. ["English (US)", "Deutsch"]
    property int layoutIdx: 0
    property bool layoutSeen: false         // the first layout report has arrived (switching shows an OSD, starting up does not)
    readonly property string layoutName: layouts[layoutIdx] ?? ""
    // "English (US)" -> "US", "Deutsch" -> "DE"
    readonly property string layoutShort: {
        const m = /\(([^)]+)\)/.exec(layoutName)
        return (m ? m[1] : layoutName.slice(0, 2)).toUpperCase()
    }

    // First open window belonging to a desktop entry (matched on app_id), or null.
    function appWindow(entry) {
        if (!entry) return null
        const ids = [entry.id, entry.startupClass, entry.name].filter(x => x).map(x => x.toLowerCase())
        return windows.find(w => w.app_id && ids.includes(w.app_id.toLowerCase())) ?? null
    }
    function switchLayout(dir) { Quickshell.execDetached(["niri", "msg", "action", "switch-layout", dir === "prev" ? "prev" : "next"]) }
    function focusWindow(id) { Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)]) }

    function refreshWorkspaces() { wsProc.running = true; outProc.running = true }
    function refreshWindows() { allWinProc.running = true }
    function refresh() { refreshWorkspaces(); refreshWindows() }
    function focusWorkspace(idx) { Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]) }

    Process {
        id: wsProc
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.workspaces = JSON.parse(text).sort((a, b) => a.idx - b.idx) } catch (e) {}
            }
        }
    }
    Process {
        id: allWinProc
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.windows = JSON.parse(text) } catch (e) {} }
        }
    }
    Process {
        id: layoutProc
        command: ["niri", "msg", "-j", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: { try { const k = JSON.parse(text); root.setLayouts(k.names, k.current_idx) } catch (e) {} }
        }
    }
    Process {
        id: outProc
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.focusedOutput = JSON.parse(text).name } catch (e) {} }
        }
    }
    // Event names from `niri msg -j event-stream` (one JSON object per line, keyed by event name).
    readonly property var ignoredEvents: ["WindowLayoutsChanged",
        "OverviewOpenedOrClosed", "ConfigLoaded", "ScreenshotCaptured", "WorkspaceUrgencyChanged", "WindowUrgencyChanged"]
    readonly property var windowEvents: ["WindowsChanged", "WindowOpenedOrChanged", "WindowClosed"]
    readonly property var workspaceEvents: ["WorkspacesChanged", "WorkspaceActivated", "WorkspaceActiveWindowChanged"]
    property bool staleWorkspaces: false
    property bool staleWindows: false
    property bool staleOutput: false      // keyboard focus moved: the focused output may have changed

    // A window that is already known and only changed (its title, mostly: browser tabs change it all
    // the time) is patched from the event itself, so no `niri msg windows` process is needed.
    // Opening a window still asks niri, which keeps the list in niri's own order.
    function patchWindow(w) {
        if (!w || w.id === undefined) return false
        const i = windows.findIndex(x => x.id === w.id)
        if (i < 0) return false
        const list = windows.slice()
        list[i] = w
        windows = list
        return true
    }
    function dropWindow(id) {
        if (id === undefined || !windows.some(x => x.id === id)) return false
        windows = windows.filter(x => x.id !== id)
        return true
    }

    function setLayouts(names, idx) {
        const switched = layoutSeen && layouts.length > 1 && idx !== layoutIdx
        layouts = names; layoutIdx = idx; layoutSeen = true
        if (switched) Osd.showText("layout", layoutName, true)
    }

    function handleEvent(line) {
        let ev = null, name = ""
        try { ev = JSON.parse(line); name = Object.keys(ev)[0] } catch (e) {}      // unparsable: refresh everything
        if (name === "KeyboardLayoutsChanged") { const k = ev[name].keyboard_layouts; setLayouts(k.names, k.current_idx); return }
        if (name === "KeyboardLayoutSwitched") { setLayouts(layouts, ev[name].idx); return }
        if (ignoredEvents.includes(name)) return
        const body = ev && ev[name] ? ev[name] : {}
        if (name === "WindowOpenedOrChanged" && patchWindow(body.window)) return
        if (name === "WindowClosed" && dropWindow(body.id)) return
        if (name === "WindowFocusChanged") staleOutput = true
        else if (windowEvents.includes(name)) staleWindows = true
        else if (workspaceEvents.includes(name)) staleWorkspaces = true
        else { staleWorkspaces = true; staleWindows = true }              // unknown event: refresh everything
        debounce.restart()
    }

    Process {
        running: true
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser { onRead: line => root.handleEvent(line) }
    }
    Timer {
        id: debounce
        interval: 40
        onTriggered: {
            if (root.staleWorkspaces) root.refreshWorkspaces()          // includes the focused output
            else if (root.staleOutput) outProc.running = true
            if (root.staleWindows) root.refreshWindows()
            root.staleWorkspaces = false
            root.staleWindows = false
            root.staleOutput = false
        }
    }
    Component.onCompleted: { refresh(); layoutProc.running = true }
}
