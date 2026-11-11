.pragma library

// The pure parts of the notification daemon (services/Notifications.qml), kept apart so they can be tested.

// Urgency levels of the freedesktop notification spec (the same numbers as NotificationUrgency).
var LOW = 0, NORMAL = 1, CRITICAL = 2

// How long a popup stays, in ms; 0 = until the user deals with it. Urgent ones stay. A sender's own timeout
// (seconds, as it arrives) is honoured up to 30 s; "never expires" (0) and "don't care" (-1) get a default.
function timeoutMs(urgency, expireTimeout) {
    if (urgency === CRITICAL) return 0
    if (expireTimeout > 0) return Math.min(expireTimeout, 30) * 1000
    if (expireTimeout === 0) return 15000
    return urgency === LOW ? 4000 : 7000
}

// "now", "3m", "2h", "5d" for something that arrived at `t` (ms since epoch); "" when unknown.
function ago(t, now) {
    if (!t) return ""
    const s = Math.max(0, (now - t) / 1000)
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    return Math.floor(s / 86400) + "d"
}

// The saved history (JSON text) as clean records; anything malformed is dropped, odd optional fields get defaults.
function parseSaved(text) {
    let saved = []
    try {
        const j = JSON.parse(text)
        if (Array.isArray(j)) saved = j.filter(r => r && typeof r.key === "string" && typeof r.app === "string" && typeof r.summary === "string"
                                                   && typeof r.body === "string" && typeof r.time === "number")
    } catch (e) {}
    return saved.map(r => ({ key: r.key, id: Number.isInteger(r.id) ? r.id : -1, app: r.app, summary: r.summary,
                body: r.body, icon: typeof r.icon === "string" ? r.icon : "", image: typeof r.image === "string" ? r.image : "",
                entry: typeof r.entry === "string" ? r.entry : "", urgency: Number.isInteger(r.urgency) ? r.urgency : 1, time: r.time }))
}
