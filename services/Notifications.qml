pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "../config"
import "dnd.js" as Dnd
import "notif.js" as Notif

// The notification daemon: ushell owns org.freedesktop.Notifications, so stop mako / dunst / swaync
// (only one program can own that name). Messages that arrive are kept in a history (the bell in the top
// pill) and shown as popups in the top-right corner, unless Do Not Disturb is on.
//
//   popups   shown on screen, newest first, at most maxPopups; they hide themselves (see timeoutMs)
//   log      every message, newest first, at most maxLog; kept across `Reload shell` and (Settings → Notifications) restarts.
//            A record of one that is still alive can run its actions; an older one is only text.
//   transient messages (the sender asked for no history, e.g. "volume 40%") are popup-only
Singleton {
    id: root

    readonly property int maxPopups: 4
    readonly property int maxLog: 200

    readonly property bool dnd: Prefs.doNotDisturb                  // the switch
    function setDnd(on) { Prefs.set("doNotDisturb", on) }
    function toggleDnd() { setDnd(!dnd) }

    // Quiet hours: Do Not Disturb every day between Prefs.dndFrom and Prefs.dndTo (see services/dnd.js).
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool scheduled: Prefs.dndSchedule && Dnd.inWindow(Prefs.dndFrom, Prefs.dndTo, clock.date)
    readonly property bool silent: dnd || scheduled || Prefs.focusMode                  // popups are held back, for either reason

    // Apps whose popups are switched off for good (their messages still reach the history).
    function isMuted(app) { return app !== "" && Prefs.mutedApps.includes(app) }
    function mute(app)   { if (app !== "" && !isMuted(app)) Prefs.set("mutedApps", Prefs.mutedApps.concat([app])) }
    function unmute(app) { Prefs.set("mutedApps", Prefs.mutedApps.filter(a => a !== app)) }

    property var log: []                       // records, newest first: { key, id, app, summary, body, icon, image, entry, urgency, time }
    property var liveKeys: ({})                // id of a live notification -> key of its record
    readonly property int count: log.length
    property int unread: 0                     // arrived while the history panel was closed
    function markRead() { unread = 0 }

    property var popupIds: []                  // ids of the notifications on screen, oldest first
    readonly property var popups: server.trackedNotifications.values.filter(n => popupIds.includes(n.id)).reverse()

    // ---- timing -------------------------------------------------------------------------------------------
    // How long a popup stays, in ms; 0 = until the user deals with it. Urgent ones stay. A sender's own timeout
    // is honoured (up to 30 s); "never expires" (0) and "don't care" (-1) get a default, the history keeps them.
    function timeoutMs(n) { return Notif.timeoutMs(n.urgency, n.expireTimeout) }

    property var arrivals: ({})                // id -> Date.now(), for "3m"
    property int tick: 0                       // bumped every 30 s so those labels refresh
    function ago(n) {
        tick
        return Notif.ago(n.stub === true ? n.time : arrivals[n.id], Date.now())
    }
    Timer { interval: 30000; repeat: true; running: root.popups.length > 0 || Shell.overlay === "notifications"; onTriggered: root.tick++ }

    // ---- the popup stack --------------------------------------------------------------------------------
    function byId(id) { return server.trackedNotifications.values.find(n => n.id === id) }

    function show(n) {
        const live = server.trackedNotifications.values.map(x => x.id)
        let ids = popupIds.filter(i => live.includes(i) && i !== n.id)
        ids.push(n.id)
        const dropped = ids.length > maxPopups ? ids.slice(0, ids.length - maxPopups) : []
        popupIds = ids.slice(dropped.length)
        for (const id of dropped) { const old = byId(id); if (old && old.transient) old.expire() }   // popup-only ones have nowhere else to live
    }
    // The popup is done (timed out or closed by hand); the message stays in the history.
    function hide(n) {
        popupIds = popupIds.filter(i => i !== n.id)
        if (n.transient && n.tracked) n.expire()
    }
    // Gone for good, from the popups and the history.
    function dismiss(n) {
        if (n.stub === true) { removeKey(n.stubKey); return }
        popupIds = popupIds.filter(i => i !== n.id)
        if (n.tracked) n.dismiss()
        removeLive(n.id)
    }
    function clear() {
        popupIds = []
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
        liveKeys = ({})
        log = []
        saveSoon()
    }
    // everything from one app
    function clearApp(app) {
        for (const r of log.filter(r => r.app === app)) {
            const n = liveOf(r)
            if (n) dismiss(n); else removeKey(r.key)
        }
    }

    // ---- the log -------------------------------------------------------------------------------------------
    property int seq: 0
    function record(n) {
        const img = n.image || ""
        return { key: Date.now().toString(36) + "-" + (seq++), id: n.id, app: n.appName, summary: n.summary, body: n.body,
                 icon: n.appIcon || "", image: img, entry: n.desktopEntry || "", urgency: n.urgency, time: Date.now() }
    }
    function liveOf(rec) { return liveKeys[rec.id] === rec.key ? (byId(rec.id) ?? null) : null }
    // the live notification of a record, or a read-only stand-in with the same fields for the card to draw
    function view(rec) {
        const n = liveOf(rec)
        if (n) return n
        return { stub: true, stubKey: rec.key, id: -1, tracked: false, resident: false, actions: [], time: rec.time,
                 appName: rec.app, summary: rec.summary, body: rec.body, image: rec.image, appIcon: rec.icon,
                 desktopEntry: rec.entry, urgency: rec.urgency }
    }
    function removeKey(key) {
        if (!log.some(r => r.key === key)) return
        log = log.filter(r => r.key !== key)
        saveSoon()
    }
    function removeLive(id) {
        const key = liveKeys[id]
        if (key === undefined) return
        delete liveKeys[id]
        removeKey(key)
    }
    function addRecord(n) {
        const rec = record(n)
        liveKeys[n.id] = rec.key
        const l = [rec].concat(log)
        const dropped = l.splice(maxLog)
        log = l
        for (const d of dropped) { const old = liveOf(d); if (old) old.dismiss() }
        saveSoon()
    }
    function updateRecord(n) {
        const key = liveKeys[n.id]
        if (key === undefined) return
        log = log.map(r => r.key === key ? Object.assign({}, r, { summary: n.summary, body: n.body, time: Date.now() }) : r)
        saveSoon()
    }

    // saved as JSON in the state folder (readable by the user only); images the sender passed in memory are not kept
    property bool logLoaded: false             // the saved log has been read
    function saveNow() {
        if (!StateDir.ready) return
        const keep = Prefs.notificationLog ? log.map(r => Object.assign({}, r, { image: /^(file:|\/)/.test(r.image) ? r.image : "" })) : []
        logFile.setText(JSON.stringify(keep))
    }
    function saveSoon() { if (logLoaded) saver.restart() }
    Timer { id: saver; interval: 600; onTriggered: root.saveNow() }
    Connections { target: Prefs; function onNotificationLogChanged() { root.saveSoon() } }

    function restore(text) {
        const have = new Set(log.map(r => r.key))
        const old = Notif.parseSaved(text).filter(r => !have.has(r.key))
        const merged = log.concat(old).sort((a, b) => b.time - a.time).slice(0, maxLog)
        // live notifications kept over a reload find their old record again; strangers get one of their own
        const taken = new Set(Object.values(liveKeys))
        for (const n of server.trackedNotifications.values) {
            if (n.transient || liveKeys[n.id] !== undefined) continue
            const rec = merged.find(r => !taken.has(r.key) && r.id === n.id && r.app === n.appName && r.summary === n.summary)
            if (rec) { liveKeys[n.id] = rec.key; taken.add(rec.key) }
            else { const r = record(n); r.time = 0; liveKeys[n.id] = r.key; merged.push(r) }
        }
        log = merged
        logLoaded = true
        saveSoon()
    }
    FileView {
        id: logFile
        path: StateDir.ready ? StateDir.dir + "/notifications.json" : ""
        watchChanges: false
        printErrors: false
        onLoaded: root.restore(logFile.text())
        onLoadFailed: root.restore("[]")
    }
    function invoke(n, action) {
        action.invoke()
        hide(n)
        if (n.tracked && !n.resident) n.dismiss()      // answered: it is done (resident ones stay until dismissed)
    }

    // Urgent messages always get through; everything else waits in the history while DND, quiet hours or the app's mute applies.
    function silenced(n) { return (silent || isMuted(n.appName)) && n.urgency !== NotificationUrgency.Critical }

    function arrived(n) {
        n.tracked = true
        arrivals[n.id] = Date.now()
        if (!n.transient) {
            if (Shell.overlay !== "notifications") unread++
            addRecord(n)
        }
        if (silenced(n)) { if (n.transient) n.expire(); return }
        show(n)
    }
    // A sender updating a message in place (a track change, a download counter) shows it again.
    function updated(n) {
        if (n.tracked) { arrivals[n.id] = Date.now(); updateRecord(n) }
        if (n.tracked && !silenced(n)) show(n)
    }

    function test() {
        Quickshell.execDetached(["notify-send", "-a", "ushell", "ushell notifications", "This is how a normal message looks."])
        Quickshell.execDetached(["notify-send", "-a", "ushell", "-u", "critical", "Urgent message", "Urgent ones stay until you click them."])
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false     // senders then send plain text, which is shown as is
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root.arrived(n)
    }

    Instantiator {
        model: server.trackedNotifications
        delegate: QtObject {
            id: watcher
            required property var modelData
            property var conn: Connections {
                target: watcher.modelData
                function onSummaryChanged() { root.updated(watcher.modelData) }
                function onBodyChanged() { root.updated(watcher.modelData) }
                function onClosed(reason) { root.removeLive(watcher.modelData.id) }      // dismissed here, or withdrawn by its sender
            }
        }
    }
}
