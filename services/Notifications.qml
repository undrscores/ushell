pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../config"
import "dnd.js" as Dnd

// The notification daemon: ushell owns org.freedesktop.Notifications, so stop mako / dunst / swaync
// (only one program can own that name). Messages that arrive are kept in a history (the bell in the top
// pill) and shown as popups in the top-right corner, unless Do Not Disturb is on.
//
//   popups   shown on screen, newest first, at most maxPopups; they hide themselves (see timeoutMs)
//   history  every message since the shell started, newest first, at most maxHistory; kept across `Reload shell`
//   transient messages (the sender asked for no history, e.g. "volume 40%") are popup-only
Singleton {
    id: root

    readonly property int maxPopups: 4
    readonly property int maxHistory: 50

    readonly property bool dnd: Prefs.doNotDisturb                  // the switch
    function setDnd(on) { Prefs.set("doNotDisturb", on) }
    function toggleDnd() { setDnd(!dnd) }

    // Quiet hours: Do Not Disturb every day between Prefs.dndFrom and Prefs.dndTo (see services/dnd.js).
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool scheduled: Prefs.dndSchedule && Dnd.inWindow(Prefs.dndFrom, Prefs.dndTo, clock.date)
    readonly property bool silent: dnd || scheduled                  // popups are held back, for either reason

    // Apps whose popups are switched off for good (their messages still reach the history).
    function isMuted(app) { return app !== "" && Prefs.mutedApps.includes(app) }
    function mute(app)   { if (app !== "" && !isMuted(app)) Prefs.set("mutedApps", Prefs.mutedApps.concat([app])) }
    function unmute(app) { Prefs.set("mutedApps", Prefs.mutedApps.filter(a => a !== app)) }

    readonly property var history: server.trackedNotifications.values.filter(n => !n.transient).reverse()
    readonly property int count: history.length
    property int unread: 0                     // arrived while the history panel was closed
    function markRead() { unread = 0 }

    property var popupIds: []                  // ids of the notifications on screen, oldest first
    readonly property var popups: server.trackedNotifications.values.filter(n => popupIds.includes(n.id)).reverse()

    // ---- timing -------------------------------------------------------------------------------------------
    // How long a popup stays, in ms; 0 = until the user deals with it. Urgent ones stay. A sender's own timeout
    // is honoured (up to 30 s); "never expires" (0) and "don't care" (-1) get a default, the history keeps them.
    function timeoutMs(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0
        if (n.expireTimeout > 0) return Math.min(n.expireTimeout, 30) * 1000
        if (n.expireTimeout === 0) return 15000
        return n.urgency === NotificationUrgency.Low ? 4000 : 7000
    }

    property var arrivals: ({})                // id -> Date.now(), for "3m"
    property int tick: 0                       // bumped every 30 s so those labels refresh
    function ago(n) {
        tick
        const t = arrivals[n.id]
        if (t === undefined) return ""
        const s = Math.max(0, (Date.now() - t) / 1000)
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
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
        popupIds = popupIds.filter(i => i !== n.id)
        if (n.tracked) n.dismiss()
    }
    function clear() {
        popupIds = []
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
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
            const h = history
            for (let i = h.length - 1; i >= maxHistory; i--) h[i].dismiss()      // the oldest ones
        }
        if (silenced(n)) { if (n.transient) n.expire(); return }
        show(n)
    }
    // A sender updating a message in place (a track change, a download counter) shows it again.
    function updated(n) {
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
            }
        }
    }
}
