pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Night light: a warm screen tint, done by running wlsunset at a fixed colour temperature while it is on.
// Needs the `wlsunset` program; without it `available` is false and the switch does nothing.
Singleton {
    id: root
    property bool available: false          // wlsunset is installed
    property bool failed: false             // it started and quit straight away (compositor without gamma control?)
    readonly property bool on: Prefs.nightLight && available && !failed
    readonly property int temp: Prefs.nightTemp

    function sync() {
        if (on) { if (proc.running) proc.signal(15); else proc.running = true }   // a running one restarts via onExited with the new temperature
        else if (proc.running) proc.signal(15)
    }
    onOnChanged: sync()
    onTempChanged: if (proc.running) proc.signal(15)
    Connections { target: Prefs; function onNightLightChanged() { root.failed = false } }

    Process {
        id: probe
        command: ["sh", "-c", "command -v wlsunset"]
        running: true
        onExited: code => { root.available = code === 0; root.sync() }
    }

    Process {
        id: proc
        property real started: 0
        // wlsunset wants a low and a high temperature; the same value (+1) keeps it constant all day
        command: ["wlsunset", "-t", String(root.temp), "-T", String(root.temp + 1)]
        onRunningChanged: if (running) started = Date.now()
        onExited: {
            if (!Prefs.nightLight || !root.available) return
            if (Date.now() - started < 1500) root.failed = true
            else running = true
        }
    }
}
