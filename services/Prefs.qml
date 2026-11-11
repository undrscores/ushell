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
    property bool offscreenPips: true    // edge markers pointing at windows outside the viewport
    property bool overviewLabels: true   // icon and title over windows when zoomed far out
    property real overviewZoom: 0.5      // labels start to fade in below this zoom
    property bool zoomAutoHide: true     // the top pill hides itself while zoomed out below overviewZoom
    property bool hotCorners: true       // corner zones that glow and run an action when the pointer rests in them
    property string hotCornerTL: "uwc:overview"
    property string hotCornerTR: "shell:minimap"
    property string hotCornerBL: ""
    property string hotCornerBR: ""
    property int hotCornerDwell: 350     // ms the pointer has to rest in the corner
    property bool compositorColors: true // window borders, glow and snap guides in uwc follow the shell's theme
    property bool widgetsPanel: false    // the top-right control centre (System / Weather / Focus tabs); off by default
    property real glassOpacity: -1       // panel opacity 0.3..1 set in Appearance; -1 = use config.json (default 0.78)
    property bool frostedPanels: true    // ask the compositor to blur behind panels (ext-background-effect-v1)
    property bool mediaCapsule: true     // now-playing capsule at the bottom left
    property bool radialMenu: true       // radial quick-action menu in the bottom right corner
    property bool dockEnabled: false     // macOS-style dock auto-hidden on the left edge, pops out on hover
    property var dockApps: ["firefox.desktop", "foot.desktop", "yazi.desktop"]  // pinned apps: desktop entry ids, top to bottom
    property bool weatherMetric: true
    property string weatherCity: ""      // empty = locate by IP address
    property string themeMode: "dark"    // dark | light
    property string accent: "mauve"      // see config/palette.js (unknown names fall back to mauve there)
    property string wallpaper: ""        // picture path; empty = ushell draws no wallpaper
    property string wallpaperDir: ""     // folder of wallpapers set in Appearance; empty = config.json / the usual places (see Wallpapers.qml)
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
    property var monitorWallpapers: ({}) // screen name -> picture path, for screens that do not show the main wallpaper
    property bool themeSchedule: false   // switch between light and dark by the time of day
    property string themeLightFrom: "07:00"   // light theme from here ...
    property string themeDarkFrom: "19:00"    // ... until here, dark the rest of the day
    property bool scheduleNightLight: true    // the night light follows the dark part of the schedule
    property bool polkitAgent: true      // ushell shows the password prompt for privileged actions (needs the other polkit agents stopped)
    property bool recordAudio: false     // screen recordings include the default audio output
    property int captureDelay: 0         // seconds to wait before a screenshot or recording starts (0, 3, 5, 10)
    property bool notificationLog: true  // keep the notification history on disk across restarts
    property int batteryWarnPct: 15      // warn when the battery drops to this percentage; 0 = never
    property bool autoPowerSaver: false  // switch to the power-saver profile when the battery is low and discharging

    // setting name -> "is this a valid value?"
    readonly property var schema: ({
        topAutoHide:     v => typeof v === "boolean",
        offscreenPips:   v => typeof v === "boolean",
        overviewLabels:  v => typeof v === "boolean",
        overviewZoom:    v => typeof v === "number" && v > 0.05 && v <= 1,
        zoomAutoHide:    v => typeof v === "boolean",
        hotCorners:      v => typeof v === "boolean",
        hotCornerTL:     v => typeof v === "string",
        hotCornerTR:     v => typeof v === "string",
        hotCornerBL:     v => typeof v === "string",
        hotCornerBR:     v => typeof v === "string",
        hotCornerDwell:  v => typeof v === "number" && v >= 50 && v <= 3000,
        compositorColors: v => typeof v === "boolean",
        frostedPanels:   v => typeof v === "boolean",
        mediaCapsule:    v => typeof v === "boolean",
        radialMenu:      v => typeof v === "boolean",
        dockEnabled:     v => typeof v === "boolean",
        dockApps:        v => Array.isArray(v) && v.every(x => typeof x === "string" && x !== ""),
        weatherMetric:   v => typeof v === "boolean",
        weatherCity:     v => typeof v === "string",
        themeMode:       v => v === "dark" || v === "light",
        accent:          v => typeof v === "string",
        wallpaper:       v => typeof v === "string",
        wallpaperDir:    v => typeof v === "string",
        widgetsPanel:    v => typeof v === "boolean",
        glassOpacity:    v => typeof v === "number" && isFinite(v) && (v === -1 || (v >= 0.3 && v <= 1)),
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
        idleOffMin:      v => Number.isInteger(v) && v >= 0 && v <= 240,
        monitorWallpapers: v => v !== null && typeof v === "object" && !Array.isArray(v) && Object.keys(v).every(k => k !== "" && typeof v[k] === "string" && v[k] !== ""),
        themeSchedule:   v => typeof v === "boolean",
        themeLightFrom:  v => typeof v === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(v),
        themeDarkFrom:   v => typeof v === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(v),
        scheduleNightLight: v => typeof v === "boolean",
        polkitAgent:     v => typeof v === "boolean",
        recordAudio:     v => typeof v === "boolean",
        captureDelay:    v => Number.isInteger(v) && v >= 0 && v <= 30,
        notificationLog: v => typeof v === "boolean",
        batteryWarnPct:  v => Number.isInteger(v) && v >= 0 && v <= 50,
        autoPowerSaver:  v => typeof v === "boolean"
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

    function snapshot() {
        const out = {}
        for (const k of Object.keys(schema)) out[k] = root[k]
        return out
    }
    function has(key) { return Object.prototype.hasOwnProperty.call(schema, key) }
    function valid(key, value) { return has(key) && schema[key](value) }
    function save() { file.setText(JSON.stringify(snapshot())) }

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
