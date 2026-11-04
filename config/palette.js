.pragma library

// Colour palettes (Catppuccin Mocha for dark, Latte for light) and the accent choices.
// Pure data plus one function, so Theme.qml stays small and this can be tested without Quickshell.

var BASE = {
    dark:  { bg: "#1e1e2e", surface: "#313244", surfaceHi: "#45475a", fg: "#cdd6f4", fgDim: "#7f849c",
             danger: "#f38ba8", ok: "#a6e3a1", ink: "#ffffff", sheen: 0.055 },
    light: { bg: "#eff1f5", surface: "#ccd0da", surfaceHi: "#bcc0cc", fg: "#4c4f69", fgDim: "#6c6f85",
             danger: "#d20f39", ok: "#40a02b", ink: "#4c4f69", sheen: 0.55 }
}

// name: [dark, light]
var ACCENTS = {
    mauve:    ["#cba6f7", "#8839ef"],
    pink:     ["#f5c2e7", "#ea76cb"],
    red:      ["#f38ba8", "#d20f39"],
    peach:    ["#fab387", "#fe640b"],
    yellow:   ["#f9e2af", "#df8e1d"],
    green:    ["#a6e3a1", "#40a02b"],
    teal:     ["#94e2d5", "#179299"],
    sapphire: ["#74c7ec", "#209fb5"],
    blue:     ["#89b4fa", "#1e66f5"],
    lavender: ["#b4befe", "#7287fd"]
}
var names = ["mauve", "pink", "red", "peach", "yellow", "green", "teal", "sapphire", "blue", "lavender"]

function has(obj, key) { return Object.prototype.hasOwnProperty.call(obj, key) }

// rough perceived brightness, 0..1 (enough to choose dark or light text on top of a colour)
function luma(hex) {
    const n = parseInt(hex.slice(1), 16)
    return (0.2126 * ((n >> 16) & 255) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255)) / 255
}

// Unknown mode or accent names fall back to dark / mauve, so a bad pref can never break the theme.
function make(mode, accentName) {
    const m = has(BASE, mode) ? mode : "dark"
    const a = has(ACCENTS, accentName) ? accentName : "mauve"
    const base = BASE[m]
    const i = m === "light" ? 1 : 0
    const accent = ACCENTS[a][i]
    return {
        mode: m, accentName: a,
        bg: base.bg, surface: base.surface, surfaceHi: base.surfaceHi,
        fg: base.fg, fgDim: base.fgDim, danger: base.danger, ok: base.ok,
        ink: base.ink, sheen: base.sheen,
        accent: accent, accent2: ACCENTS.pink[i],
        accentFg: luma(accent) > 0.48 ? "#1e1e2e" : "#eff1f5"
    }
}
