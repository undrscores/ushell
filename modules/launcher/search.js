.pragma library

// Query parsing and fuzzy scoring for the launcher (pure functions).

// `shortcuts`: { name: url } web search shortcuts ("yt cats" searches that site); see Config.searchShortcuts.
function parse(text, shortcuts) {
    let m
    if (text.trim() === "?") return { mode: "help", q: "" }
    if ((m = text.match(/^>\s?(.*)$/))) return { mode: "cmd", q: m[1].trim() }
    if ((m = text.match(/^(e|emoji)\s+(.*)$/i))) return { mode: "emoji", q: m[2].trim() }
    if ((m = text.match(/^(c|clip|clipboard)\s+(.*)$/i))) return { mode: "clip", q: m[2].trim() }
    if (shortcuts && (m = text.match(/^([a-z0-9]{1,12})\s+(.*)$/i)) && Object.prototype.hasOwnProperty.call(shortcuts, m[1].toLowerCase()))
        return { mode: "web", q: m[2].trim(), url: shortcuts[m[1].toLowerCase()] }
    if ((m = text.match(/^(z|zy|zypper)\s+(.*)$/i))) return { mode: "pkg",  q: m[2].trim() }
    if ((m = text.match(/^(m|music)\s+(.*)$/i)))     return { mode: "song", q: m[2].trim() }
    if ((m = text.match(/^(f|file|files)\s+(.*)$/i))) return { mode: "file", q: m[2].trim() }
    if ((m = text.match(/^(g|web)\s+(.*)$/i)))       return { mode: "web",  q: m[2].trim() }
    return { mode: "app", q: text.trim() }
}

// Higher is better, 0 = no match.
function textScore(name, q) {
    if (name === q) return 100
    if (name.startsWith(q)) return 80
    if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 65
    if (name.includes(q)) return 50
    let i = 0
    for (const c of name) if (c === q[i]) i++
    return i === q.length ? 15 : 0
}
function appScore(app, q) {
    const s = textScore(app.name.toLowerCase(), q)
    if (s > 15) return s
    const extra = ((app.genericName ?? "") + " " + (app.keywords ?? []).join(" ") + " " + (app.comment ?? "")).toLowerCase()
    return extra.includes(q) ? 30 : s
}
