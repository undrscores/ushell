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

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function hex2(v) { const h = Math.round(clamp(v, 0, 1) * 255).toString(16); return h.length < 2 ? "0" + h : h }

// HSV (hue 0..360, s and v 0..1) -> "#rrggbb"
function hsv(h, s, v) {
    h = ((h % 360) + 360) % 360
    const c = v * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = v - c
    const k = Math.floor(h / 60)
    const rgb = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]][Math.min(5, k)]
    return "#" + hex2(rgb[0] + m) + hex2(rgb[1] + m) + hex2(rgb[2] + m)
}

// HSL (hue 0..360, s and l 0..1) -> "#rrggbb"
function hsl(h, s, l) {
    const v = l + s * Math.min(l, 1 - l)
    return hsv(h, v === 0 ? 0 : 2 * (1 - l / v), v)
}

// WCAG relative luminance and contrast ratio of "#rrggbb" colours
function lum(hex) {
    const n = parseInt(hex.slice(1), 16)
    const f = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * f((n >> 16) & 255) + 0.7152 * f((n >> 8) & 255) + 0.0722 * f(n & 255)
}
function contrast(a, b) {
    const x = lum(a), y = lum(b)
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}

// An accent in the style of the named ones (soft and bright on dark, deeper on light) for any hue.
// `sat` is how colourful the source was, 0..1; it only nudges the result. The colour is then eased
// (paler on dark, darker on light) until it stands out from the background well enough to read.
function fromHue(mode, hue, sat, bg, surface) {
    const s = clamp(isFinite(sat) ? sat : 0.5, 0, 1)
    if (mode === "light") {
        const sa = clamp(0.55 + 0.4 * s, 0.6, 0.9)
        let v = 0.85, c = hsv(hue, sa, v)
        while ((contrast(c, bg || BASE.light.bg) < 3.5 || contrast(c, surface || BASE.light.surface) < 3) && v > 0.4) { v -= 0.03; c = hsv(hue, sa, v) }
        return c
    }
    let sa = clamp(0.22 + 0.3 * s, 0.28, 0.5), c = hsv(hue, sa, 0.97)      // the named dark accents sit at 0.24-0.45
    while ((contrast(c, bg || BASE.dark.bg) < 4.5 || contrast(c, surface || BASE.dark.surface) < 3) && sa > 0.2) { sa -= 0.02; c = hsv(hue, sa, 0.97) }
    return c
}

// Background, surfaces and text tinted with a hue, laid out like the Catppuccin greys (which carry a hint of blue).
// Lightness steps are fixed and then nudged until the text is readable whatever the hue turns out to be.
function neutrals(mode, hue, sat) {
    const s = clamp(isFinite(sat) ? sat : 0.5, 0, 1)
    const t = clamp(0.12 + 0.12 * s, 0.12, 0.24)         // how strongly the greys lean toward the hue
    const light = mode === "light"
    const bg = hsl(hue, light ? t + 0.06 : t, light ? 0.95 : 0.15)
    let fgL = light ? 0.30 : 0.88, dimL = light ? 0.43 : 0.58
    let fg = hsl(hue, light ? t * 0.8 : t * 2.2, fgL), fgDim = hsl(hue, t * 0.6, dimL)
    const step = light ? -0.02 : 0.02
    while (contrast(fg, bg) < 7 && fgL > 0.05 && fgL < 0.99) { fgL += step; fg = hsl(hue, light ? t * 0.8 : t * 2.2, fgL) }
    while (contrast(fgDim, bg) < 4 && dimL > 0.05 && dimL < 0.99) { dimL += step; fgDim = hsl(hue, t * 0.6, dimL) }
    return {
        bg: bg,
        surface:   hsl(hue, t * 0.8,  light ? 0.83 : 0.23),
        surfaceHi: hsl(hue, t * 0.65, light ? 0.77 : 0.31),
        fg: fg, fgDim: fgDim,
        ink: light ? fg : "#ffffff"
    }
}

// Unknown mode or accent names fall back to dark / mauve, so a bad pref can never break the theme.
// `auto` ({ hue, sat }, optional) overrides the named accent, e.g. with the wallpaper's colour.
function make(mode, accentName, auto) {
    const m = has(BASE, mode) ? mode : "dark"
    const a = has(ACCENTS, accentName) ? accentName : "mauve"
    const base = BASE[m]
    const i = m === "light" ? 1 : 0
    const custom = !!auto && typeof auto.hue === "number" && isFinite(auto.hue)
    const n = custom ? neutrals(m, auto.hue, auto.sat) : base
    const accent = custom ? fromHue(m, auto.hue, auto.sat, n.bg, n.surface) : ACCENTS[a][i]
    return {
        mode: m, accentName: custom ? "auto" : a,
        bg: n.bg, surface: n.surface, surfaceHi: n.surfaceHi,
        fg: n.fg, fgDim: n.fgDim, danger: base.danger, ok: base.ok,
        ink: n.ink, sheen: base.sheen,
        accent: accent, accent2: custom ? fromHue(m, auto.hue + 40, auto.sat, n.bg, n.surface) : ACCENTS.pink[i],
        accentFg: contrast(accent, "#1e1e2e") >= contrast(accent, "#eff1f5") ? "#1e1e2e" : "#eff1f5"
    }
}
