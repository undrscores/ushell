pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// System stats for the System tab. Polls only while that tab is on screen.
// Two pollers: the cheap one (/proc, /sys, df) every 1.5 s, and nvidia-smi (a heavier process) every 3 s.
Singleton {
    id: root
    property real cpu: 0
    property var cpuHistory: new Array(40).fill(0)
    property real cpuTemp: 0     // °C: Tctl on AMD (k10temp), package temperature on Intel (coretemp)
    property bool hasCpuTemp: false
    property real mem: 0
    property real memUsed: 0     // GB
    property real memTotal: 0    // GB
    property real swap: 0
    property bool hasGpu: false
    property real gpu: 0
    property real gpuTemp: 0
    property bool hasGpuTemp: false
    property real gpuPower: 0    // W
    property bool hasGpuPower: false
    property real gpuClock: 0    // MHz (graphics clock)
    property bool hasGpuClock: false
    property real vram: 0
    property real vramUsed: 0    // GB
    property real vramTotal: 0   // GB
    property var disks: []       // [{ label, used, size, frac }]  (GB), one per filesystem
    property real load: 0
    property real uptime: 0      // seconds
    property var prev: null

    // nvidia-smi missing or failing (no NVIDIA driver, another vendor): after 3 failures in a row it is not
    // asked again until the System tab is opened the next time.
    property int gpuFailures: 0

    readonly property bool wanted: (Shell.widgetsShown || Shell.widgetsPinned) && Shell.widgetsTab === 0
    onWantedChanged: if (wanted) gpuFailures = 0

    Timer {
        interval: 1500
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.wanted && root.gpuFailures < 3
        triggeredOnStart: true
        onTriggered: gpuProc.running = true
    }
    Process {
        id: proc
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo;" +
            // source first: two mounts on one device (or one btrfs pool) are listed once, under the first mount
            "echo '#disk'; df -B1 --output=source,target,size,used / /home 2>/dev/null | tail -n +2;" +
            "echo '#load'; cut -d' ' -f1 /proc/loadavg; cut -d' ' -f1 /proc/uptime;" +
            "echo '#temp'; for d in /sys/class/hwmon/hwmon*; do case \"$(cat \"$d/name\" 2>/dev/null)\" in" +
            " k10temp|coretemp|zenpower) cat \"$d/temp1_input\" 2>/dev/null && break;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
    Process {
        id: gpuProc
        command: ["sh", "-c",
            "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,clocks.gr" +
            " --format=csv,noheader,nounits 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseGpu(text)
        }
    }

    function parse(text) {
        const lines = text.split("\n")
        let section = "mem"
        const kv = {}
        const diskList = []
        const seenDevices = {}
        const loadList = []
        const tempList = []
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
                const p = l.split(/\s+/)                      // source target size used
                if (p.length < 4 || seenDevices[p[0]]) continue
                seenDevices[p[0]] = true
                const size = parseFloat(p[2]) / 1e9, used = parseFloat(p[3]) / 1e9
                diskList.push({ label: p[1], used: used, size: size, frac: size > 0 ? used / size : 0 })
            } else if (section === "load") loadList.push(parseFloat(l))
            else if (section === "temp") tempList.push(parseFloat(l))
        }
        memTotal = kv.MemTotal || 0
        memUsed = memTotal - (kv.MemAvailable || 0)
        mem = memTotal > 0 ? memUsed / memTotal : 0
        swap = kv.SwapTotal > 0 ? 1 - kv.SwapFree / kv.SwapTotal : 0
        root.disks = diskList
        root.load = loadList[0] || 0
        uptime = loadList[1] || 0
        hasCpuTemp = tempList.length > 0 && isFinite(tempList[0])
        if (hasCpuTemp) cpuTemp = tempList[0] / 1000      // millidegrees
    }

    // One line per GPU; the first one is shown. Optional columns print "[N/A]" on some cards.
    function parseGpu(text) {
        const line = text.split("\n").map(s => s.trim()).find(s => s !== "") || ""
        const g = line.split(",").map(x => parseFloat(x))
        if (g.length < 4 || isNaN(g[0]) || isNaN(g[2]) || isNaN(g[3])) {
            hasGpu = false
            gpuFailures++
            return
        }
        gpuFailures = 0
        hasGpu = true
        gpu = g[0] / 100
        hasGpuTemp = isFinite(g[1]); if (hasGpuTemp) gpuTemp = g[1]
        vramUsed = g[2] / 1024; vramTotal = g[3] / 1024
        vram = vramTotal > 0 ? vramUsed / vramTotal : 0
        hasGpuPower = isFinite(g[4]); if (hasGpuPower) gpuPower = g[4]
        hasGpuClock = isFinite(g[5]); if (hasGpuClock) gpuClock = g[5]
    }
}
