pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// CPU / memory usage. Only polls while the widgets panel is visible.
Singleton {
    id: root
    property real cpu: 0
    property real mem: 0
    property var prev: null

    Timer {
        interval: 2000
        repeat: true
        running: Shell.widgetsShown || Shell.widgetsPinned
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
    Process {
        id: proc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const L = text.split("\n")
                const c = L[0].trim().split(/\s+/).slice(1, 9).map(Number)
                const idle = c[3] + c[4]
                const total = c.reduce((a, b) => a + b, 0)
                if (root.prev) {
                    const dt = total - root.prev.total, di = idle - root.prev.idle
                    root.cpu = dt > 0 ? 1 - di / dt : 0
                }
                root.prev = { total: total, idle: idle }
                const mt = parseInt(L[1].trim().split(/\s+/)[1]), ma = parseInt(L[2].trim().split(/\s+/)[1])
                root.mem = mt > 0 ? 1 - ma / mt : 0
            }
        }
    }
}
