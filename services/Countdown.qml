pragma Singleton
import Quickshell
import QtQuick

// A countdown timer (focus sessions, tea, ...). Lives in the widgets panel's Focus tab; while it runs
// the bar shows the time left. When it reaches zero it plays a sound and shows an OSD pill.
Singleton {
    id: root
    property int total: 25 * 60          // seconds it is set to
    property real left: 25 * 60          // seconds left while idle or paused
    property real endsAt: 0              // when it will finish (ms since epoch) while running
    property bool running: false
    property real clock: Date.now()      // ticks while running, so `remaining` re-evaluates
    readonly property real remaining: running ? Math.max(0, (endsAt - clock) / 1000) : left
    readonly property bool active: running || left < total   // started at some point and not reset
    readonly property real fraction: total > 0 ? remaining / total : 0

    function fmt(sec) {
        const s = Math.ceil(sec)
        const m = Math.floor(s / 60), r = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
    }

    function setMinutes(m) {
        if (running || !(m > 0 && m <= 600)) return
        total = Math.round(m * 60)
        left = total
    }
    function start() {
        if (running) return
        if (left <= 0) left = total
        clock = Date.now()
        endsAt = clock + left * 1000
        running = true
    }
    function pause() {
        if (!running) return
        left = remaining
        running = false
    }
    function toggle() { running ? pause() : start() }
    function reset() { running = false; left = total }

    function finish() {
        running = false
        left = total
        Osd.showText("timer", "Timer done", true)
        Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"])
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: {
            root.clock = Date.now()
            if (root.clock >= root.endsAt) root.finish()
        }
    }
}
