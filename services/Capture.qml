pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

// Screenshots and screen recordings.
//
// Screenshots use `grim` (and `slurp` for a region): the picture goes to the clipboard (`wl-copy`) and to
// Config.screenshotDir. Recordings use `wf-recorder` (and `slurp` for a region); without them `canRecord`
// is false and the panel says what to install.
//
//   qs ipc call capture <region|screen|window|record|recordRegion|stop|toggle|status>
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property bool canRecord: false           // wf-recorder is installed
    property bool canPick: false             // slurp is installed (region recordings)
    property bool recording: false
    property bool picking: false             // waiting for the region to be drawn
    property real startedAt: 0
    property int elapsed: 0                  // seconds since the recording started
    property string lastFile: ""
    property int countdown: 0                // seconds left before a delayed capture fires
    property string pending: ""              // what the countdown will do

    readonly property bool busy: recording || picking || countdown > 0

    function expand(p) { return p.startsWith("~/") ? home + p.slice(1) : p }
    function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") }
    function fmt(s) {
        const m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // Run after the panel has left the screen (it would be in the picture) and the optional delay.
    function later(what, fn) {
        Shell.close()
        pending = what
        countdown = Prefs.captureDelay
        action = fn
        settle.restart()
    }
    property var action: null
    Timer {
        id: settle
        interval: Theme.animSlow + 60
        onTriggered: { if (root.countdown > 0) tick.start(); else root.fire() }
    }
    Timer {
        id: tick
        interval: 1000; repeat: true
        onTriggered: {
            root.countdown--
            if (root.countdown <= 0) { tick.stop(); root.fire() }
            else Osd.showText("note", root.pending + " in " + root.countdown, true, "")
        }
    }
    function fire() {
        const f = action
        action = null
        pending = ""
        countdown = 0
        if (f) f()
    }
    function cancel() { tick.stop(); settle.stop(); action = null; pending = ""; countdown = 0 }

    // ---- screenshots -----------------------------------------------------------------------------------
    // region: drawn with slurp. screen / window: the focused output / window straight away.
    function screenshot(kind) {
        if (busy) return
        later("Screenshot", () => {
            const dir = expand(Config.screenshotDir)
            const file = dir + "/screenshot-" + stamp() + ".png"
            let sel = ""                                       // what to pass to grim, as shell words
            if (kind === "screen") sel = Wm.focusedOutput !== "" ? "-o '" + Wm.focusedOutput + "'" : ""
            else if (kind === "window") {
                const g = Wm.focusedWindowGeometry()
                if (!g) return
                sel = "-g '" + g + "'"
            }
            const cmd = kind === "region"
                ? "mkdir -p \"$1\" && g=$(slurp -f '%x,%y %wx%h') && grim -g \"$g\" \"$2\" && wl-copy < \"$2\""
                : "mkdir -p \"$1\" && grim " + sel + " \"$2\" && wl-copy < \"$2\""
            Quickshell.execDetached(["sh", "-c", cmd, "sh", dir, file])
        })
    }

    // ---- recording -------------------------------------------------------------------------------------
    function record(region) {
        if (busy || !canRecord) return
        if (region && !canPick) return
        later("Recording", () => region ? pick.running = true : begin(""))
    }

    function begin(geometry) {
        const dir = expand(Config.recordingDir)
        const file = dir + "/recording-" + stamp() + ".mp4"
        const args = geometry !== "" ? ["-g", geometry] : (Wm.focusedOutput !== "" ? ["-o", Wm.focusedOutput] : [])
        if (Prefs.recordAudio) args.push("--audio")
        lastFile = file
        rec.command = ["sh", "-c", "d=$1; f=$2; shift 2; mkdir -p \"$d\" && exec wf-recorder -f \"$f\" \"$@\"", "sh", dir, file].concat(args)
        rec.running = true
    }

    function stopRecording() { if (rec.running) rec.signal(2) }        // SIGINT: wf-recorder finishes the file
    function toggleRecording() { if (recording) stopRecording(); else record(false) }

    Process {
        id: probe
        command: ["sh", "-c", "command -v wf-recorder >/dev/null && echo rec; command -v slurp >/dev/null && echo pick; true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.canRecord = text.includes("rec"); root.canPick = text.includes("pick") }
        }
    }

    // slurp prints "x,y WxH" for the drawn region; Esc gives nothing and the recording is dropped
    Process {
        id: pick
        command: ["slurp", "-f", "%x,%y %wx%h"]
        onRunningChanged: root.picking = running
        stdout: StdioCollector {
            onStreamFinished: { const g = text.trim(); if (g !== "") root.begin(g) }
        }
    }

    Process {
        id: rec
        property string err: ""
        onRunningChanged: {
            if (running) {
                err = ""
                root.startedAt = Date.now(); root.elapsed = 0; root.recording = true
                Osd.showText("note", "Recording started", true, "\uf03d")
            }
        }
        // wf-recorder exits 0 after Ctrl+C (SIGINT); anything else means no usable file (bad region, no compositor support ...)
        onExited: code => {
            const was = root.recording
            root.recording = false
            if (!was) return
            if (code === 0) {
                const name = root.lastFile.slice(root.lastFile.lastIndexOf("/") + 1)
                Osd.showText("note", "Saved " + name, true, "\uf03d")
            } else {
                const why = err.trim().split("\n").pop()
                console.warn("ushell capture: wf-recorder exited with " + code + (why ? ": " + why : ""))
                Osd.showText("note", "Recording failed" + (why ? ": " + why : ""), true, "\uf071")
            }
        }
        stderr: StdioCollector { onStreamFinished: rec.err = text }
    }
    Timer {
        interval: 1000; repeat: true; running: root.recording
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }

    // reveal the last recording in the default file manager
    function openFolder() { Quickshell.execDetached(["xdg-open", expand(Config.recordingDir)]) }
}
