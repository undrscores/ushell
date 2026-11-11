import QtQuick
import "../config"

// Keeps uwc's window colours (focus border, urgent, shadow glow, snap guides) in step with the shell's
// theme, so the accent you pick, light or dark, or the wallpaper's colours show up on the window borders too.
// Pushes over uwc's `set` (live until uwc reloads its config; a reload is noticed through `config_rev` and the
// colours are pushed again). Off with Prefs.compositorColors. Put one of these in shell.qml.
Item {
    id: root
    readonly property bool on: Prefs.compositorColors && Uwc.connected
    readonly property int rev: Uwc.state.config_rev ?? 0
    // our own `set`s bump config_rev too; this many are still to come back, the rest is a reload
    property int pending: 0
    property int lastRev: -1

    function hex(c, a) {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0")
        return "#" + h(c.r) + h(c.g) + h(c.b) + (a === undefined ? "" : h(a))
    }
    readonly property var lines: [
        'focus-gradient "' + hex(Theme.accent) + '" "' + hex(Theme.accent2) + '"',
        'border-color "' + hex(Theme.surfaceHi) + '"',
        'urgent-color "' + hex(Theme.danger) + '"',
        'focus-shadow-color "' + hex(Theme.accent, 0.4) + '"',
        'snap-color "' + hex(Theme.accent2) + '"'
    ]
    function push() {
        if (!on) return
        for (const l of lines) Uwc.send("set " + l)
        pending += lines.length
        lastRev = -2                       // the replies below re-sync lastRev
        sync.restart()
    }
    // after our sets settled, remember the revision they ended on
    Timer { id: sync; interval: 400; onTriggered: { root.pending = 0; root.lastRev = root.rev } }

    onRevChanged: {
        if (!on) { lastRev = rev; return }
        if (lastRev === -2) return
        const d = rev - lastRev
        lastRev = rev
        if (lastRev < 0 || d <= 0 || d > pending) { pending = 0; push() }   // first state, uwc restarted, or a reload
        else pending -= d
    }
    onOnChanged: if (on) push()

    Timer {
        id: settle
        interval: 700                                   // after the colour fade
        running: true
        onTriggered: root.push()
    }
    readonly property string sig: lines.join("|")
    onSigChanged: settle.restart()
}
