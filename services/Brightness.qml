pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Monitor brightness over DDC/CI (ddcutil) — these monitors have no kernel backlight.
// ddcutil is slow (~1s per call), so writes are throttled and coalesced: dragging a
// slider updates the UI instantly and sends only the latest value.
// Monitors are detected on first use (quick settings opened, or a brightness keybind), not at login.
Singleton {
    id: root
    property var displays: []         // [{ bus, name, value }]  value 0..100
    property bool ready: false
    property bool missing: false      // no DDC-capable monitor found
    property bool detecting: false
    readonly property real average: displays.length ? displays.reduce((a, d) => a + d.value, 0) / displays.length : 0

    property var pending: ({})        // bus -> value waiting to be written
    property var queue: []            // buses still to read during detection

    function ensure() { if (!ready && !detecting) detect() }
    function detect() { detecting = true; missing = false; displays = []; detectProc.running = true }

    function set(bus, value) {
        value = Math.round(Math.max(0, Math.min(100, value)))
        displays = displays.map(d => d.bus === bus ? { bus: d.bus, name: d.name, value: value } : d)
        pending[bus] = value
        flush.restart()
    }
    // Relative change for all monitors. The very first call also triggers detection and is applied once that finishes.
    property real queuedStep: 0
    function step(delta) {
        if (!ready) { if (!missing) { queuedStep += delta; ensure() } return }
        for (const d of displays) set(d.bus, d.value + delta)
    }

    function writeNext() {
        if (writer.running) return
        const bus = Object.keys(pending)[0]
        if (bus === undefined) return
        const v = pending[bus]
        delete pending[bus]
        writer.command = ["ddcutil", "--bus", bus, "setvcp", "10", String(v), "--noverify"]
        writer.running = true
    }
    Timer { id: flush; interval: 150; onTriggered: root.writeNext() }
    Process { id: writer; onRunningChanged: if (!running) root.writeNext() }

    Process {
        id: detectProc
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                let cur = null
                for (const line of text.split("\n")) {
                    const b = line.match(/I2C bus:\s+\/dev\/i2c-(\d+)/)
                    if (b) { cur = { bus: b[1], name: "Monitor", value: 0 }; found.push(cur); continue }
                    const m = line.match(/Monitor:\s+(\S*):(\S*):/)
                    if (m && cur) cur.name = (m[1] + " " + m[2]).trim()
                }
                root.queue = found
                root.displays = found
                root.readNext()
            }
        }
    }

    function readNext() {
        if (queue.length === 0) {
            detecting = false
            ready = displays.length > 0
            missing = displays.length === 0
            const queued = queuedStep
            queuedStep = 0
            if (ready && queued !== 0) step(queued)
            return
        }
        readProc.bus = queue[0].bus
        readProc.running = true
    }
    Process {
        id: readProc
        property string bus: ""
        command: ["ddcutil", "--bus", bus, "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/VCP 10 C (\d+) (\d+)/)
                if (m) {
                    const max = parseInt(m[2]) || 100
                    const v = Math.round(parseInt(m[1]) * 100 / max)
                    root.displays = root.displays.map(d => d.bus === readProc.bus ? { bus: d.bus, name: d.name, value: v } : d)
                } else {
                    root.displays = root.displays.filter(d => d.bus !== readProc.bus)
                }
                root.queue = root.queue.slice(1)
                root.readNext()
            }
        }
    }
}
