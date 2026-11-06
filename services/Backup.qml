pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Export the shell's settings (the choices made in Settings plus config.json) to one file, and bring them back.
//   qs ipc call settings save [PATH]        (default ~/ushell-settings.json)
//   qs ipc call settings restore [PATH]
// An import goes through the same checks as every other change: values that are not valid are skipped.
Singleton {
    id: root
    readonly property string defaultPath: StateDir.home + "/ushell-settings.json"
    property string status: ""             // the last result, for the About page
    property bool failed: false
    property bool busy: false
    property string path: ""

    function say(text, bad) { status = text; failed = bad === true; busy = false }

    function exportTo(p) {
        if (busy) return
        path = (p && p !== "") ? p : defaultPath
        busy = true
        status = ""
        exportProc.command = ["python3", "-I", Quickshell.shellPath("services/backup.py"), "export", path, JSON.stringify(Prefs.snapshot())]
        exportProc.running = true
    }
    function importFrom(p) {
        if (busy) return
        path = (p && p !== "") ? p : defaultPath
        busy = true
        status = ""
        readProc.command = ["python3", "-I", Quickshell.shellPath("services/backup.py"), "read", path]
        readProc.running = true
    }

    function result(text) {
        try { return JSON.parse(text.trim().split("\n").pop()) } catch (e) { return { ok: false, error: "the backup helper did not run (is python3 installed?)" } }
    }

    Process {
        id: exportProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.result(text)
                if (r.ok) root.say("Saved " + r.prefs + " settings to " + r.path.replace(StateDir.home, "~"))
                else root.say("Export failed: " + (r.error || "unknown error"), true)
            }
        }
    }

    property int applied: 0
    property int skipped: 0
    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.result(text)
                if (!r.ok) { root.say("Import failed: " + (r.error || "unknown error"), true); return }
                let ok = 0, bad = 0
                for (const k of Object.keys(r.prefs)) {
                    if (Prefs.has(k) && Prefs.valid(k, r.prefs[k])) { Prefs.set(k, r.prefs[k]); ok++ } else bad++
                }
                root.applied = ok; root.skipped = bad
                if (Object.keys(r.config).length > 0) {
                    configProc.command = ["python3", "-I", Quickshell.shellPath("services/backup.py"), "writeconfig", JSON.stringify(r.config)]
                    configProc.running = true
                }
                else root.finish()
            }
        }
    }
    function finish() {
        say("Imported " + applied + " settings" + (skipped > 0 ? " (" + skipped + " skipped)" : "") + " from " + path.replace(StateDir.home, "~"))
    }
    Process {
        id: configProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.result(text)
                if (r.ok) root.finish()
                else root.say("Settings imported, but config.json was not written: " + (r.error || "unknown error"), true)
            }
        }
    }
}
