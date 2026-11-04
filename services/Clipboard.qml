pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history. `wl-paste --watch` feeds clipboard_store.py, which keeps a JSON
// file; this singleton just reads it (and reloads whenever it changes).
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string file: home + "/.local/state/quickshell-config/clipboard.json"
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
    function copy(text) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text])
    }

    FileView {
        id: store
        path: root.file
        watchChanges: true
        onLoaded: root.parse(store.text())
        onFileChanged: reload()
    }

    Process {
        running: true
        command: ["wl-paste", "--type", "text", "--watch", "python3", "-I", root.script, "store"]
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", home + "/.local/state/quickshell-config"])
}
