pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"
import "wall.js" as Wall

// The wallpaper library (pictures in Config.wallpaperDir) and the colour taken from the current wallpaper.
// ushell only draws a wallpaper once one has been chosen (Prefs.wallpaper); until then another
// wallpaper program, if you use one, is left alone.
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    function expand(p) { return p.startsWith("~") ? home + p.slice(1) : p }
    // The folder the user chose (Appearance settings, else config.json) ...
    readonly property string wanted: expand((Prefs.wallpaperDir !== "" ? Prefs.wallpaperDir : Config.wallpaperDir).trim())
    // ... or, if that folder does not exist, the first of the usual places that does, so no setup is needed.
    property string found: ""
    readonly property string dir: found !== "" ? found : wanted
    onWantedChanged: probe()
    Component.onCompleted: probe()
    function probe() { probeProc.running = false; probeProc.running = true }
    Process {
        id: probeProc
        command: ["sh", "-c", 'for d in "$@"; do [ -d "$d" ] && { printf %s "$d"; exit 0; }; done', "sh",
                  root.wanted, root.home + "/Pictures/Wallpapers", root.home + "/Pictures/wallpapers", root.home + "/Wallpapers", root.home + "/wallpapers"]
        stdout: StdioCollector {
            onStreamFinished: { root.found = text.trim(); root.refresh() }
        }
    }
    readonly property string script: Quickshell.shellPath("services/wallpaper_colors.py")
    readonly property string current: Prefs.wallpaper

    property var files: []              // absolute paths, sorted by name
    property bool scanned: false
    // The picture that could not be loaded (moved, deleted, corrupt). While it is the chosen one ushell
    // draws nothing, so whatever is behind (another wallpaper program) shows through.
    property string failed: ""

    // file:// URL for a path (spaces, #, % and so on are escaped)
    function url(path) { return Wall.url(path) }
    function nameOf(path) { return Wall.nameOf(path) }

    // ── favourites and folders (for the picker) ─────────────────────────────
    readonly property var favs: Prefs.wallpaperFavs
    function isFav(path) { return favs.includes(path) }
    function toggleFav(path) {
        if (path) Prefs.set("wallpaperFavs", isFav(path) ? favs.filter(p => p !== path) : favs.concat([path]))
    }
    // the sub-folder of the library a picture is in ("" for loose files)
    function folderOf(path) { return Wall.folderOf(dir, path) }
    readonly property var folders: Array.from(new Set(files.map(folderOf).filter(f => f !== ""))).sort((a, b) => a.localeCompare(b))

    // ── choosing ────────────────────────────────────────────────────────────
    function set(path) { failed = ""; Prefs.set("wallpaper", path) }
    function off() { Prefs.set("wallpaper", "") }

    // ── one picture per screen ───────────────────────────────────────────────
    // A screen listed in Prefs.monitorWallpapers shows its own picture; every other screen shows the main one
    // (which also colours the theme).
    function pathFor(screenName) { return Prefs.monitorWallpapers[screenName] || Prefs.wallpaper }
    readonly property bool anyOverride: Object.keys(Prefs.monitorWallpapers).length > 0
    function setFor(screenName, path) {
        if (!screenName || !path) return
        failed = ""
        const m = Object.assign({}, Prefs.monitorWallpapers)
        m[screenName] = path
        Prefs.set("monitorWallpapers", m)
    }
    function resetFor(screenName) {
        const m = Object.assign({}, Prefs.monitorWallpapers)
        delete m[screenName]
        Prefs.set("monitorWallpapers", m)
    }
    function moveFor(screenName, d) { setFor(screenName, Wall.stepFrom(files, pathFor(screenName), d)) }
    function randomFor(screenName) { setFor(screenName, Wall.randomFrom(files, "", Math.random())) }

    // next / previous / random re-scan the folder first, so new pictures are picked up
    property var afterScan: null
    function refresh() { scanProc.running = false; scanProc.running = true }
    function next() { afterScan = () => move(1); refresh() }
    function prev() { afterScan = () => move(-1); refresh() }
    function random() { afterScan = () => pickRandom(); refresh() }
    function move(d) { const p = Wall.stepFrom(files, current, d); if (p !== "") set(p) }
    function pickRandom() { const p = Wall.randomFrom(files, current, Math.random()); if (p !== "") set(p) }
    // qs ipc call shell wallpaper <next|prev|random|off|/path/to/picture>
    // qs ipc call shell wallpaper OUTPUT=<next|prev|random|off|/path>   one screen only ("off" gives it back the main wallpaper)
    function command(arg) {
        const c = Wall.parseCommand(arg)
        if (c === null) return
        if (c.output === "") {
            if (c.action === "next") next()
            else if (c.action === "prev") prev()
            else if (c.action === "random") random()
            else if (c.action === "off") off()
            else set(c.path)
        } else if (c.action === "off") resetFor(c.output)
        else if (c.action === "set") setFor(c.output, c.path)
        else { afterScan = () => (c.action === "next" ? moveFor(c.output, 1) : c.action === "prev" ? moveFor(c.output, -1) : randomFor(c.output)); refresh() }
    }

    Process {
        id: scanProc
        command: ["find", "-L", root.dir, "-maxdepth", "2", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l !== "")
                list.sort((a, b) => a.localeCompare(b))
                root.files = list
                root.scanned = true
                if (root.failed !== "" && root.files.includes(root.failed)) root.failed = ""     // it is back: try it again
                if (root.afterScan) { const f = root.afterScan; root.afterScan = null; f() }
            }
        }
    }

    // ── colours from the wallpaper ──────────────────────────────────────────
    property real hue: -1
    property real sat: 0
    property real hue2: -1              // second colour of the picture, -1 = none
    property real sat2: 0
    property bool colorsOk: false       // false: off, not read yet, failed, or the picture has no colour (grey)
    property bool colorsRead: false     // the reader has finished for the current picture
    property string colorError: ""      // why it failed, e.g. no image decoder for a JPEG (shown in the Appearance panel)
    readonly property bool useColors: Prefs.wallpaperColors && colorsOk

    // Safe to call at any time and any number of times (it is also triggered when Prefs finishes loading,
    // so it doesn't matter in which order the saved settings were applied).
    function extract() {
        if (!Prefs.wallpaperColors || current === "") { colorError = ""; return }
        if (colorProc.running && colorProc.path === current) return
        colorsRead = false
        colorError = ""
        colorProc.path = current
        colorProc.running = false
        colorProc.running = true
    }
    Connections {
        target: Prefs
        function onWallpaperChanged() { root.extract() }
        function onWallpaperColorsChanged() { root.extract() }
        function onLoadedChanged() { root.extract() }
    }
    Timer { id: again; interval: 100; onTriggered: root.extract() }

    Process {
        id: colorProc
        property string path: ""
        command: ["python3", "-I", root.script, colorProc.path]
        stdout: StdioCollector {
            onStreamFinished: {
                if (colorProc.path !== root.current) { again.restart(); return }     // changed while it was running
                let j = null
                try { j = JSON.parse(text) } catch (e) {}
                if (j && typeof j.hue === "number") { root.hue = j.hue; root.sat = j.sat ?? 0.5; root.hue2 = typeof j.hue2 === "number" ? j.hue2 : -1; root.sat2 = j.sat2 ?? 0; root.colorsOk = true; root.colorError = "" }
                else {
                    root.colorsOk = false
                    // {"error": ...} from the script; no output at all means it never ran (python3 missing?)
                    root.colorError = j ? (j.error || "") : "the colour reader did not run (is python3 installed?)"
                    if (root.colorError !== "") console.warn("ushell wallpaper colours: " + root.colorError)
                }
                root.colorsRead = true
            }
        }
    }
}
