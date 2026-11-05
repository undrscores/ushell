pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Where ushell keeps its state (prefs, clipboard history, launcher ranking):
// $XDG_STATE_HOME/ushell, or ~/.local/state/ushell. (services/*.py compute the same path.)
// The first run copies the old quickshell-config directory over; anything that reads or writes
// state waits for `ready` so it never races that migration. (The old cover-art cache in
// $XDG_CACHE_HOME/quickshell-config is not touched: it is only a cache, and can be deleted by hand.)
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string base: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string dir: base + "/ushell"
    readonly property string legacy: base + "/quickshell-config"
    property bool ready: false

    Process {
        running: true
        command: ["sh", "-c",
            "if [ ! -d \"$1\" ] && [ -d \"$2\" ]; then cp -a \"$2\" \"$1\"; else mkdir -p \"$1\"; fi;"
            + " chmod 700 \"$1\"; chmod 600 \"$1\"/clipboard.json 2>/dev/null; exit 0",
            "sh", root.dir, root.legacy]
        onExited: root.ready = true
    }
}
