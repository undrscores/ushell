.pragma library

// Validation for the user's config.json. Every key is checked on its own: a wrong one keeps its
// default and produces a warning (shown in `qs log`), the rest of the file still applies.

function isText(v) { return typeof v === "string" && v.trim() !== "" }
function isTextList(v) { return Array.isArray(v) && v.every(isText) }

var RULES = {
    pinnedApps:   { ok: isTextList,                                    fix: v => v.map(s => s.trim()),                        hint: "a list of app names" },
    terminal:     { ok: isText,                                        fix: v => v.trim(),                                    hint: "a command name" },
    lockCommand:  { ok: v => isTextList(v) && v.length > 0,            fix: v => v.map(s => s.trim()),                        hint: "a non-empty list: the command and its arguments" },
    searchUrl:    { ok: v => typeof v === "string" && /^https?:\/\/\S+$/.test(v.trim()), fix: v => v.trim(),                   hint: "an http(s) URL the search text is appended to" },
    wallpaperDir: { ok: isText,                                        fix: v => v.trim(),                                    hint: "a folder path (~ is your home)" },
    glassOpacity: { ok: v => typeof v === "number" && isFinite(v),     fix: v => Math.max(0.5, Math.min(1, v)),               hint: "a number from 0.5 to 1" },
    maxVolume:    { ok: v => typeof v === "number" && isFinite(v),     fix: v => Math.max(1, Math.min(1.5, v)),               hint: "a number from 1 to 1.5 (1 = 100%)" }
}

// text: the file's contents.  defaults: { key: value }.   Returns { values, warnings }.
function parse(text, defaults) {
    const values = {}
    for (const k of Object.keys(defaults)) values[k] = defaults[k]
    const warnings = []

    let json
    try { json = JSON.parse(text) } catch (e) { return { values: values, warnings: ["not valid JSON (" + e.message + "), using defaults"] } }
    if (json === null || typeof json !== "object" || Array.isArray(json))
        return { values: values, warnings: ["the top level must be an object { ... }, using defaults"] }

    for (const k of Object.keys(json)) {
        if (!Object.prototype.hasOwnProperty.call(RULES, k)) { warnings.push("unknown setting \"" + k + "\" (ignored)"); continue }
        if (!RULES[k].ok(json[k])) { warnings.push("\"" + k + "\" should be " + RULES[k].hint + " (keeping the default)"); continue }
        values[k] = RULES[k].fix(json[k])
    }
    return { values: values, warnings: warnings }
}
