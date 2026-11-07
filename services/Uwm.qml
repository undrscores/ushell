pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// uwm's IPC socket ($UWM_SOCKET, set when the shell runs inside uwm; absent elsewhere).
// Display state (monitors, their modes and scale) and the commands to change it, with a
// keep-or-revert timer so a bad mode cannot leave you with a blank screen.
Singleton {
    id: root
    readonly property string socketPath: Quickshell.env("UWM_SOCKET") ?? ""
    readonly property bool available: socketPath !== ""
    readonly property bool connected: sock.connected
    property var state: ({ monitors: [], windows: [], selmon: "" })
    readonly property var monitors: state.monitors

    // a change waiting for confirmation: { name, prev: { w, h, hz, scale }, left }
    property var pending: null
    readonly property int revertAfter: 10

    function send(cmd) {
        if (!sock.connected) return
        sock.write(cmd + "\n")
        sock.flush()
    }
    function modeOf(mon) { return mon ? (mon.modes.find(m => m.current) ?? null) : null }
    function hzText(hz) { return (Math.round(hz * 10) / 10) + " Hz" }
    // distinct resolutions of a monitor, largest first
    function resolutions(mon) {
        const seen = {}, out = []
        for (const m of mon.modes) {
            const k = m.width + "x" + m.height
            if (!seen[k]) { seen[k] = true; out.push({ key: k, width: m.width, height: m.height }) }
        }
        return out.sort((a, b) => b.width * b.height - a.width * a.height)
    }
    // modes of one resolution, fastest first
    function rates(mon, w, h) {
        return mon.modes.filter(m => m.width === w && m.height === h).sort((a, b) => b.refresh - a.refresh)
    }

    function setMode(mon, w, h, hz) {          // hz 0 = the highest available
        arm(mon)
        send("mode " + mon.name + " " + w + " " + h + (hz > 0 ? " " + hz : ""))
    }
    function setScale(mon, scale) {
        arm(mon)
        send("scale " + mon.name + " " + scale)
    }
    function arm(mon) {
        const cur = modeOf(mon)
        if (!pending && cur)
            pending = { name: mon.name, prev: { w: cur.width, h: cur.height, hz: cur.refresh, scale: mon.scale }, left: revertAfter }
    }
    function keep() { pending = null }
    function revert() {
        if (!pending) return
        const p = pending
        pending = null
        send("mode " + p.name + " " + p.prev.w + " " + p.prev.h + " " + p.prev.hz)
        send("scale " + p.name + " " + p.prev.scale)
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pending !== null
        onTriggered: {
            if (root.pending.left <= 1) root.revert()
            else root.pending = Object.assign({}, root.pending, { left: root.pending.left - 1 })
        }
    }

    Socket {
        id: sock
        path: root.socketPath
        connected: root.available
        parser: SplitParser {
            onRead: line => {
                let ev = null
                try { ev = JSON.parse(line) } catch (e) { return }
                if (ev.event === "state") root.state = ev
                else if (ev.error) console.warn("uwm: " + ev.error)
            }
        }
        onConnectedChanged: if (connected) root.send("subscribe")
    }

    // uwm restarted or the socket was not up yet: keep trying
    Timer {
        interval: 1000
        repeat: true
        running: root.available && !sock.connected
        onTriggered: sock.connected = true
    }
}
