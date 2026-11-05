.pragma library

// Quiet-hours check for the Do Not Disturb schedule. Times are "HH:MM" strings.

function minutes(hhmm) {
    const m = /^(\d\d):(\d\d)$/.exec(hhmm)
    if (!m) return -1
    const h = parseInt(m[1]), mi = parseInt(m[2])
    return h < 24 && mi < 60 ? h * 60 + mi : -1
}

// Is `now` (a Date) inside the daily window from..to? The window may cross midnight (22:00 to 07:00).
// from == to is an empty window, never active.
function inWindow(from, to, now) {
    const f = minutes(from), t = minutes(to)
    if (f < 0 || t < 0 || f === t) return false
    const n = now.getHours() * 60 + now.getMinutes()
    return f < t ? (n >= f && n < t) : (n >= f || n < t)
}
