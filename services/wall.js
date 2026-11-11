.pragma library

// The pure parts of the wallpaper library (services/Wallpapers.qml), kept apart so they can be tested.

// file:// URL for a path (spaces, #, % and so on are escaped)
function url(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }

function nameOf(path) {
    const n = path.slice(path.lastIndexOf("/") + 1)
    const i = n.lastIndexOf(".")
    return i > 0 ? n.slice(0, i) : n
}

// the sub-folder of the library `dir` a picture is in ("" for loose files)
function folderOf(dir, path) {
    const rel = path.slice(dir.replace(/\/+$/, "").length + 1)
    const i = rel.indexOf("/")
    return i < 0 ? "" : rel.slice(0, i)
}

// The picture `d` steps after (or before) `current` in `files`, wrapping round; "" when there are none.
// A current one that is not in the list starts at the first (forwards) or last (backwards) picture.
function stepFrom(files, current, d) {
    const n = files.length
    if (n === 0) return ""
    const i = files.indexOf(current)
    return files[i < 0 ? (d > 0 ? 0 : n - 1) : (i + d + n) % n]
}

// A random picture; never the current one when there is a choice. `r` is a number in [0, 1).
function randomFrom(files, current, r) {
    const n = files.length
    if (n === 0) return ""
    let j = Math.floor(r * n)
    if (n > 1 && files[j] === current) j = (j + 1) % n
    return files[j]
}

// `qs ipc call shell wallpaper <arg>`: next | prev | random | off | /path, optionally OUTPUT=<...> for one screen.
// Returns { output: "" | name, action: "next" | "prev" | "random" | "off" | "set", path } or null.
function parseCommand(arg) {
    let output = "", a = arg
    const m = /^([^=\/]+)=(.*)$/.exec(arg)
    if (m) { output = m[1]; a = m[2] }
    if (a === "next" || a === "prev" || a === "random" || a === "off") return { output: output, action: a, path: "" }
    if (a.startsWith("/")) return { output: output, action: "set", path: a }
    return null
}

// What the picker shows: `files` narrowed by the search text and by filter = all | favs | folder:<name>.
function filterList(files, query, filter, favs, dir) {
    const q = query.trim().toLowerCase()
    return files.filter(p => {
        if (filter === "favs" && !favs.includes(p)) return false
        if (filter.startsWith("folder:") && folderOf(dir, p) !== filter.slice(7)) return false
        return q === "" || nameOf(p).toLowerCase().includes(q)
    })
}
