pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Where ushell keeps its state (prefs, clipboard history, launcher ranking).
// The first run copies the old ~/.local/state/quickshell-config directory over; anything
// that reads or writes state waits for `ready` so it never races that migration.
Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/ushell"
    readonly property string legacy: Quickshell.env("HOME") + "/.local/state/quickshell-config"
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
