pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// System stats for the System tab. Polls only while that tab is on screen.
Singleton {
    id: root
    property real cpu: 0
    property var cpuHistory: new Array(40).fill(0)
    property real mem: 0
    property real memUsed: 0     // GB
    property real memTotal: 0    // GB
    property real swap: 0
    property bool hasGpu: false
    property real gpu: 0
    property real gpuTemp: 0
    property real vram: 0
    property real vramUsed: 0    // GB
    property real vramTotal: 0   // GB
    property var disks: []       // [{ label, used, size, frac }]  (GB)
    property real load: 0
    property real uptime: 0      // seconds
    property var prev: null

    readonly property bool wanted: (Shell.widgetsShown || Shell.widgetsPinned) && Shell.widgetsTab === 1

    Timer {
        interval: 1500
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
    Process {
        id: proc
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo;" +
            "echo '#disk'; df -B1 --output=target,size,used / /home 2>/dev/null | tail -n +2;" +
            "echo '#load'; cut -d' ' -f1 /proc/loadavg; cut -d' ' -f1 /proc/uptime;" +
            "echo '#gpu'; nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text) {
        const lines = text.split("\n")
        let section = "mem"
        const kv = {}
        const diskList = []
        const loadList = []
        let gpuLine = ""
        for (let i = 0; i < lines.length; i++) {
            const l = lines[i].trim()
            if (!l) continue
            if (l.startsWith("#")) { section = l.slice(1); continue }
            if (i === 0) {
                const c = l.split(/\s+/).slice(1, 9).map(Number)
                const idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0)
                if (prev) {
                    const dt = total - prev.total, di = idle - prev.idle
                    cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0
                    const h = cpuHistory.slice(1); h.push(cpu); cpuHistory = h
                }
                prev = { total: total, idle: idle }
            } else if (section === "mem") {
                const m = l.match(/^(\w+):\s+(\d+)/)
                if (m) kv[m[1]] = parseInt(m[2]) / 1048576   // kB -> GB
            } else if (section === "disk") {
                const p = l.split(/\s+/)
                const size = parseFloat(p[1]) / 1e9, used = parseFloat(p[2]) / 1e9
                diskList.push({ label: p[0], used: used, size: size, frac: size > 0 ? used / size : 0 })
            } else if (section === "load") loadList.push(parseFloat(l))
            else if (section === "gpu") gpuLine = l
        }
        memTotal = kv.MemTotal || 0
        memUsed = memTotal - (kv.MemAvailable || 0)
        mem = memTotal > 0 ? memUsed / memTotal : 0
        swap = kv.SwapTotal > 0 ? 1 - kv.SwapFree / kv.SwapTotal : 0
        root.disks = diskList
        root.load = loadList[0] || 0
        uptime = loadList[1] || 0
        const g = gpuLine.split(",").map(x => parseFloat(x))
        hasGpu = g.length >= 4 && !isNaN(g[0])
        if (hasGpu) {
            gpu = g[0] / 100; gpuTemp = g[1]
            vramUsed = g[2] / 1024; vramTotal = g[3] / 1024
            vram = vramTotal > 0 ? vramUsed / vramTotal : 0
        }
    }
}
