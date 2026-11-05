import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

// Keeps the colours of other programs (terminals, GTK apps, niri's borders) in step with the shell's theme,
// and so with the wallpaper when "colours from wallpaper" is on. Waits until the theme has stopped fading,
// then runs services/apply_theme.py. Put one of these in shell.qml.
Item {
    id: root
    readonly property string payload: JSON.stringify({
        mode: Theme.mode,
        bg: hex(Theme.bg), surface: hex(Theme.surface), surfaceHi: hex(Theme.surfaceHi),
        fg: hex(Theme.fg), fgDim: hex(Theme.fgDim),
        accent: hex(Theme.accent), accent2: hex(Theme.accent2), accentFg: hex(Theme.accentFg),
        danger: hex(Theme.danger), ok: hex(Theme.ok)
    })
    function hex(c) {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0")
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }

    onPayloadChanged: settle.restart()
    Timer {
        id: settle
        interval: 700                                   // after the 450 ms colour fade
        running: true
        onTriggered: {
            if (!Prefs.loaded || !StateDir.ready) { restart(); return }
            proc.running = false
            proc.command = ["python3", "-I", Quickshell.shellPath("services/apply_theme.py"), root.payload]
            proc.running = true
        }
    }
    Process {
        id: proc
        stderr: StdioCollector { onStreamFinished: if (text !== "") console.warn("ushell theme export: " + text) }
    }
}
