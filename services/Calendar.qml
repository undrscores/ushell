pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

// The calendar panel's state: the month on show, the selected day, and the events found in the .ics files
// listed in Config.calendarPaths (read by services/ics_events.py, recurring events included).
Singleton {
    id: root

    function iso(d) {
        const p = n => (n < 10 ? "0" : "") + n
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
    }
    function parseIso(s) { const a = s.split("-"); return new Date(+a[0], +a[1] - 1, +a[2]) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string today: iso(clock.date)

    property date viewMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property string selected: iso(new Date())
    property var events: []                      // as printed by the script
    property bool loading: false
    property bool failed: false
    property string loadedFor: ""                // "FROM TO" of the events held, to skip pointless reloads

    // the 6 x 7 grid: the first cell is the start of the week that holds the 1st of the month
    readonly property int firstDow: Qt.locale().firstDayOfWeek === 7 ? 0 : Qt.locale().firstDayOfWeek   // 0 = Sunday
    readonly property date gridStart: {
        const first = new Date(viewMonth.getFullYear(), viewMonth.getMonth(), 1)
        const back = (first.getDay() - firstDow + 7) % 7
        return new Date(first.getFullYear(), first.getMonth(), 1 - back)
    }
    readonly property var days: {
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i)
            out.push({ date: d, iso: iso(d), day: d.getDate(), inMonth: d.getMonth() === viewMonth.getMonth() })
        }
        return out
    }

    // iso day -> [events that touch it]
    readonly property var byDay: {
        const m = {}
        for (const e of events) {
            const s = parseIso(e.start.slice(0, 10))
            let last = parseIso(e.end.slice(0, 10))
            if (e.allDay && e.end !== e.start) last = new Date(last.getFullYear(), last.getMonth(), last.getDate() - 1)
            if (last < s) last = s
            for (let d = s, n = 0; d <= last && n < 60; d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1), n++) {
                const k = iso(d)
                if (!m[k]) m[k] = []
                m[k].push(e)
            }
        }
        for (const k of Object.keys(m)) m[k].sort((a, b) => (b.allDay - a.allDay) || a.start.localeCompare(b.start))
        return m
    }
    function eventsOn(isoDay) { return byDay[isoDay] ?? [] }

    function clockText(e, isoDay) {
        if (e.allDay) return "all day"
        const s = e.start.slice(0, 10) === isoDay ? e.start.slice(11) : "…"
        const en = e.end.slice(0, 10) === isoDay ? e.end.slice(11) : "…"
        return e.end === e.start ? s : s + " – " + en
    }

    function show(year, month) { viewMonth = new Date(year, month, 1) }
    function step(n) { viewMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + n, 1) }
    function goToday() { const n = new Date(); viewMonth = new Date(n.getFullYear(), n.getMonth(), 1); selected = iso(n) }

    function refresh() {
        const from = iso(gridStart)
        const to = iso(new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + 42))
        const key = from + " " + to + " " + Config.calendarPaths.join("|")
        if (key === loadedFor && !failed) return
        loadedFor = key
        loading = true
        failed = false
        proc.command = ["python3", "-I", Quickshell.shellPath("services/ics_events.py"), from, to]
            .concat(Config.calendarPaths.map(p => p.startsWith("~/") ? Quickshell.env("HOME") + p.slice(1) : p))
        proc.running = false
        proc.running = true
    }
    onViewMonthChanged: if (active) refresh()
    property bool active: false                   // the panel is open

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try { root.events = JSON.parse(text) } catch (e) { root.failed = true; root.events = [] }
            }
        }
    }
    function forceRefresh() { loadedFor = ""; refresh() }
}
