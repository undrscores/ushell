.pragma library

// Package search for the launcher ("z firefox"): the pure parts, so they can be tested without pacman.

// pacman and the AUR helpers take the search as a regular expression; escape it to match the typed text literally.
function escapeRegex(q) { return q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") }

// Output of `pacman -Ss` (or paru / yay -Ss): "repo/name version [installed]" followed by an indented description line.
// Returns launcher rows { kind: "pkg", title, glyph, installed, data }, the exact name first, then shorter names first.
function parseSearch(text, query) {
    const items = []
    for (const line of text.split("\n")) {
        if (line.startsWith(" ") || line.trim() === "") continue
        const m = line.match(/^[^\/\s]+\/(\S+)\s+\S+(.*)$/)
        if (!m) continue
        items.push({ kind: "pkg", title: m[1], glyph: "", installed: /[\[(]installed/i.test(m[2]), data: m[1] })
    }
    items.sort((x, y) => (y.title === query) - (x.title === query) || x.title.length - y.title.length)
    return items.slice(0, 60)
}
