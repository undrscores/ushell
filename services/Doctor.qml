pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

// Checks what ushell needs from the system (the fonts the theme names, helper programs) once at start-up,
// logs what is missing, and keeps the report for `qs -c ushell ipc call shell doctor`.
Singleton {
    id: root
    property string report: "checking…"
    property var missing: []             // the warn lines
    property bool done: false

    function run() { proc.running = false; proc.running = true }
    Component.onCompleted: run()

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("services/doctor.sh"), Theme.font, Theme.iconFont]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "")
                root.missing = lines.filter(l => l.startsWith("warn"))
                root.report = lines.join("\n")
                root.done = true
                for (const l of root.missing) console.warn("ushell doctor: " + l.replace(/^warn\s+/, ""))
            }
        }
    }
}
