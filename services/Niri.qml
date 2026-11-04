pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Thin wrapper over `niri msg`. Re-queries state (debounced) on every niri event.
Singleton {
    id: root
    property var workspaces: []
    property string title: ""
    property string focusedOutput: ""

    function refresh() { wsProc.running = true; winProc.running = true; outProc.running = true }
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
        id: outProc
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.focusedOutput = JSON.parse(text).name } catch (e) {} }
        }
    }
    Process {
        running: true
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser { onRead: debounce.restart() }
    }
    Timer { id: debounce; interval: 40; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
