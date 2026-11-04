pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history. `wl-paste --watch` feeds clipboard_store.py, which keeps a JSON
// file; this singleton just reads it (and reloads whenever it changes).
Singleton {
    id: root
    readonly property string file: StateDir.dir + "/clipboard.json"
    readonly property string script: Quickshell.shellPath("services/clipboard_store.py")

    property var items: []          // [{ id, text, time, pinned }] pinned first, then newest first

    function parse(raw) {
        let list = []
        try { list = JSON.parse(raw).items || [] } catch (e) {}
        list.sort((a, b) => (b.pinned === true) - (a.pinned === true) || b.time - a.time)
        items = list
    }

    function run(...args) { Quickshell.execDetached(["python3", "-I", script].concat(args)) }
    function remove(id) { run("delete", String(id)) }
    function togglePin(id) { run("pin", String(id)) }
    function clear() { run("clear") }
    function copy(id) { run("copy", String(id)) }     // the script pipes the text to wl-copy (no argv size limit)

    FileView {
        id: store
        path: StateDir.ready ? root.file : ""
        watchChanges: true
        onLoaded: root.parse(store.text())
        onFileChanged: reload()
    }

    // Keeps itself alive: if the watcher dies (compositor hiccup, wl-clipboard crash) it comes back.
    Process {
        id: watcher
        running: StateDir.ready
        command: ["wl-paste", "--type", "text", "--watch", "python3", "-I", root.script, "store"]
        onExited: if (StateDir.ready) restart.start()
    }
    Timer { id: restart; interval: 2000; onTriggered: watcher.running = true }
}
