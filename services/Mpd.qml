pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// MPD client. State arrives as JSON lines from services/mpd_bridge.py (stdlib python,
// speaks the MPD protocol directly, so no mpDris2 / mpd-mpris proxy is needed).
Singleton {
    id: root
    readonly property string script: Quickshell.shellPath("services/mpd_bridge.py")

    property bool online: false
    property string state: "stop"        // play | pause | stop
    property string title: ""
    property string artist: ""
    property string album: ""
    property string art: ""
    property real elapsed: 0
    property real duration: 0
    property double stamp: 0             // when `elapsed` was last updated (ms)

    readonly property bool playing: online && state === "play"
    readonly property bool active: online && state !== "stop" && title !== ""

    function send(...args) { Quickshell.execDetached(["python3", "-I", script, "cmd"].concat(args)) }
    function toggle() { send("pause", state === "play" ? "1" : "0") }
    function next()   { send("next") }
    function prev()   { send("previous") }
    function seek(sec) { send("seekcur", String(Math.max(0, sec))) }

    Process {
        id: proc
        running: true
        command: ["python3", "-I", root.script, "watch"]
        stdout: SplitParser {
            onRead: line => {
                let j
                try { j = JSON.parse(line) } catch (e) { return }
                root.online = j.online === true
                if (!root.online) { root.state = "stop"; return }
                root.state = j.state
                root.title = j.title
                root.artist = j.artist
                root.album = j.album
                root.art = j.art
                root.elapsed = j.elapsed
                root.duration = j.duration
                root.stamp = Date.now()
            }
        }
        stderr: SplitParser { onRead: line => console.warn("mpd_bridge: " + line) }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: proc.running = true }
}
