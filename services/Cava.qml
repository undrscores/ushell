pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Audio spectrum from cava (raw ascii mode, config/cava.conf).
// Only runs while music is playing AND the full player is on screen.
Singleton {
    id: root
    readonly property int count: 28
    property var bars: new Array(count).fill(0)
    readonly property real bass: bars.length >= 4 ? (bars[0] + bars[1] + bars[2] + bars[3]) / 400 : 0
    readonly property bool wanted: Media.playing && Shell.mediaFull

    Process {
        id: proc
        running: root.wanted
        command: ["cava", "-p", Quickshell.shellPath("config/cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(Number)
                if (v.length) root.bars = v
            }
        }
        onRunningChanged: if (!running) root.bars = new Array(root.count).fill(0)
    }
}
