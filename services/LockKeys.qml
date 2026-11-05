pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Caps Lock and Num Lock state, read from the keyboard LEDs (services/lockkeys.py). A change shows an OSD
// pill; what was already set when the shell started does not.
Singleton {
    id: root
    property bool caps: false
    property bool num: false
    property bool seen: false                // the first report has arrived

    Process {
        running: true
        command: ["python3", "-I", Quickshell.shellPath("services/lockkeys.py")]
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(" ")
                if (p.length !== 2) return
                const caps = p[0] === "1", num = p[1] === "1"
                const first = !root.seen
                const capsChanged = caps !== root.caps, numChanged = num !== root.num
                root.caps = caps; root.num = num; root.seen = true
                if (first) return
                if (capsChanged) Osd.showText("caps", "Caps Lock " + (caps ? "on" : "off"), caps)
                if (numChanged) Osd.showText("num", "Num Lock " + (num ? "on" : "off"), num)
            }
        }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: root.seen = false }
}
