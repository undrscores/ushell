pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// User settings, edited from the Settings / Appearance menus (or over IPC) and saved to
// prefs.json in StateDir.dir (~/.local/state/ushell by default).
//
// To add a setting: declare the property below and add one line to `schema`.
// Loading, saving and validation are all driven from that table.
Singleton {
    id: root
    property bool topAutoHide: true      // false = top pill always visible (reserves space)
    property bool leftAutoHide: true     // false = left dock always visible (reserves space)
    property bool frame: true            // a frame around the screen edges that the bar, dock and menus grow out of
    property bool mediaCapsule: true     // now-playing capsule at the bottom left
    property bool radialMenu: true       // radial quick-action menu in the bottom right corner
    property bool weatherMetric: true
    property string weatherCity: ""      // empty = locate by IP address
    property string themeMode: "dark"    // dark | light
    property string accent: "mauve"      // see config/palette.js (unknown names fall back to mauve there)
    property string wallpaper: ""        // picture path; empty = ushell draws no wallpaper
    property bool wallpaperColors: true  // the theme's colours follow the wallpaper (picking an accent in Appearance turns this off)
    property var wallpaperFavs: []       // pictures starred in the wallpaper picker (paths)
    property bool doNotDisturb: false    // no notification popups (urgent ones still show); history still fills
    property var mutedApps: []           // app names whose notifications never pop up (they still reach the history)
    property bool dndSchedule: false     // Do Not Disturb every day between dndFrom and dndTo
    property string dndFrom: "22:00"
    property string dndTo: "07:00"
    property bool focusMode: false       // silences notifications and hides the capsule and radial menu
    property bool nightLight: false      // warm screen tint (needs wlsunset)
    property int nightTemp: 4000         // its colour temperature in kelvin; lower is warmer
    property int idleLockMin: 0          // lock after this many idle minutes; 0 = never
    property int idleOffMin: 0           // turn the screens off after this many idle minutes; 0 = never

    // setting name -> "is this a valid value?"
    readonly property var schema: ({
        topAutoHide:     v => typeof v === "boolean",
        leftAutoHide:    v => typeof v === "boolean",
        frame:           v => typeof v === "boolean",
        mediaCapsule:    v => typeof v === "boolean",
        radialMenu:      v => typeof v === "boolean",
        weatherMetric:   v => typeof v === "boolean",
        weatherCity:     v => typeof v === "string",
        themeMode:       v => v === "dark" || v === "light",
        accent:          v => typeof v === "string",
        wallpaper:       v => typeof v === "string",
        wallpaperColors: v => typeof v === "boolean",
        wallpaperFavs:   v => Array.isArray(v) && v.every(x => typeof x === "string" && x !== ""),
        doNotDisturb:    v => typeof v === "boolean",
        mutedApps:       v => Array.isArray(v) && v.every(x => typeof x === "string" && x !== ""),
        dndSchedule:     v => typeof v === "boolean",
        dndFrom:         v => typeof v === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(v),
        dndTo:           v => typeof v === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(v),
        focusMode:       v => typeof v === "boolean",
        nightLight:      v => typeof v === "boolean",
        nightTemp:       v => Number.isInteger(v) && v >= 2500 && v <= 6000,
        idleLockMin:     v => Number.isInteger(v) && v >= 0 && v <= 240,
        idleOffMin:      v => Number.isInteger(v) && v >= 0 && v <= 240
    })

    // True once prefs.json has been read (or turned out not to exist). Until then a change is held back,
    // not written: saving early would overwrite the file with defaults and lose the other settings.
    property bool loaded: false
    property var queued: ({})            // changes made before `loaded`, applied once it is

    function set(key, value) {
        if (!Object.prototype.hasOwnProperty.call(schema, key) || !schema[key](value)) return
        if (!loaded) { queued[key] = value; return }
        if (root[key] === value) return
        root[key] = value
        save()
    }

    function save() {
        const out = {}
        for (const k of Object.keys(schema)) out[k] = root[k]
        file.setText(JSON.stringify(out))
    }

    function finishLoad() {
        loaded = true
        const q = queued
        queued = ({})
        let changed = false
        for (const k of Object.keys(q))
            if (root[k] !== q[k]) { root[k] = q[k]; changed = true }
        if (changed) save()
    }

    FileView {
        id: file
        path: StateDir.ready ? StateDir.dir + "/prefs.json" : ""
        watchChanges: false
        onLoaded: {
            try {
                const j = JSON.parse(file.text())
                if (j !== null && typeof j === "object")
                    for (const k of Object.keys(root.schema))
                        if (k in j && root.schema[k](j[k])) root[k] = j[k]
            } catch (e) { console.warn("ushell prefs.json: " + e.message + " (using defaults)") }
            root.finishLoad()
        }
        onLoadFailed: root.finishLoad()      // no file yet (first run) or unreadable: defaults
    }
}
