pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Thin wrapper over `niri msg`. Re-queries only what a niri event can have changed (debounced),
// and ignores events that don't affect anything shown (layout shuffles, overview, keyboard layout, ...).
Singleton {
    id: root
    property var workspaces: []
    property string title: ""
    property string focusedOutput: ""
    property var windows: []

    // First open window belonging to a desktop entry (matched on app_id), or null.
    function appWindow(entry) {
        if (!entry) return null
        const ids = [entry.id, entry.startupClass, entry.name].filter(x => x).map(x => x.toLowerCase())
        return windows.find(w => w.app_id && ids.includes(w.app_id.toLowerCase())) ?? null
    }
    function closeWindow(id) { Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(id)]) }
    function focusWindow(id) { Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)]) }

    function refreshWorkspaces() { wsProc.running = true; outProc.running = true }
    function refreshWindows() { winProc.running = true; allWinProc.running = true }
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
        id: winProc
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const w = JSON.parse(text); root.title = w ? (w.title || w.app_id || "") : "" }
                catch (e) { root.title = "" }
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
        id: outProc
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.focusedOutput = JSON.parse(text).name } catch (e) {} }
        }
    }
    // Event names from `niri msg -j event-stream` (one JSON object per line, keyed by event name).
    readonly property var ignoredEvents: ["WindowLayoutsChanged", "KeyboardLayoutsChanged", "KeyboardLayoutSwitched",
        "OverviewOpenedOrClosed", "ConfigLoaded", "ScreenshotCaptured", "WorkspaceUrgencyChanged", "WindowUrgencyChanged"]
    readonly property var windowEvents: ["WindowsChanged", "WindowOpenedOrChanged", "WindowClosed", "WindowFocusChanged"]
    property bool staleWorkspaces: false
    property bool staleWindows: false

    function handleEvent(line) {
        let name = ""
        try { name = Object.keys(JSON.parse(line))[0] } catch (e) {}      // unparsable: refresh everything
        if (ignoredEvents.includes(name)) return
        staleWindows = true                                                  // the focused title can change on any event
        if (!windowEvents.includes(name)) staleWorkspaces = true             // unknown events refresh both
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
            if (root.staleWorkspaces) root.refreshWorkspaces()
            if (root.staleWindows) root.refreshWindows()
            root.staleWorkspaces = false
            root.staleWindows = false
        }
    }
    Component.onCompleted: refresh()
}
