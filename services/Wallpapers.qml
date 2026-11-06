pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

// The wallpaper library (pictures in Config.wallpaperDir) and the colour taken from the current wallpaper.
// ushell only draws a wallpaper once one has been chosen (Prefs.wallpaper); until then another
// wallpaper program, if you use one, is left alone.
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: Config.wallpaperDir.startsWith("~") ? home + Config.wallpaperDir.slice(1) : Config.wallpaperDir
    readonly property string script: Quickshell.shellPath("services/wallpaper_colors.py")
    readonly property string current: Prefs.wallpaper

    property var files: []              // absolute paths, sorted by name
    property bool scanned: false
    // The picture that could not be loaded (moved, deleted, corrupt). While it is the chosen one ushell
    // draws nothing, so whatever is behind (another wallpaper program, niri's background) shows through.
    property string failed: ""

    // file:// URL for a path (spaces, #, % and so on are escaped)
    function url(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }
    function nameOf(path) {
        const n = path.slice(path.lastIndexOf("/") + 1)
        const i = n.lastIndexOf(".")
        return i > 0 ? n.slice(0, i) : n
    }

    // ── favourites and folders (for the picker) ─────────────────────────────
    readonly property var favs: Prefs.wallpaperFavs
    function isFav(path) { return favs.includes(path) }
    function toggleFav(path) {
        if (path) Prefs.set("wallpaperFavs", isFav(path) ? favs.filter(p => p !== path) : favs.concat([path]))
    }
    // the sub-folder of the library a picture is in ("" for loose files)
    function folderOf(path) {
        const rel = path.slice(dir.replace(/\/+$/, "").length + 1)
        const i = rel.indexOf("/")
        return i < 0 ? "" : rel.slice(0, i)
    }
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
    function moveFor(screenName, d) {
        const n = files.length
        if (n === 0) return
        const i = files.indexOf(pathFor(screenName))
        setFor(screenName, files[i < 0 ? (d > 0 ? 0 : n - 1) : (i + d + n) % n])
    }
    function randomFor(screenName) {
        const n = files.length
        if (n > 0) setFor(screenName, files[Math.floor(Math.random() * n)])
    }

    // next / previous / random re-scan the folder first, so new pictures are picked up
    property var afterScan: null
    function refresh() { scanProc.running = false; scanProc.running = true }
    function next() { afterScan = () => move(1); refresh() }
    function prev() { afterScan = () => move(-1); refresh() }
    function random() { afterScan = () => pickRandom(); refresh() }
    function move(d) {
        const n = files.length
        if (n === 0) return
        const i = files.indexOf(current)
        set(files[i < 0 ? (d > 0 ? 0 : n - 1) : (i + d + n) % n])
    }
    function pickRandom() {
        const n = files.length
        if (n === 0) return
        let j = Math.floor(Math.random() * n)
        if (n > 1 && files[j] === current) j = (j + 1) % n
        set(files[j])
    }
    // qs ipc call shell wallpaper <next|prev|random|off|/path/to/picture>
    // qs ipc call shell wallpaper OUTPUT=<next|prev|random|off|/path>   one screen only ("off" gives it back the main wallpaper)
    function command(arg) {
        const m = /^([^=\/]+)=(.*)$/.exec(arg)
        if (m) {
            const out = m[1], a = m[2]
            if (a === "off") resetFor(out)
            else if (a.startsWith("/")) setFor(out, a)
            else { afterScan = () => (a === "next" ? moveFor(out, 1) : a === "prev" ? moveFor(out, -1) : a === "random" ? randomFor(out) : null); refresh() }
            return
        }
        if (arg === "next") next()
        else if (arg === "prev") prev()
        else if (arg === "random") random()
        else if (arg === "off") off()
        else if (arg.startsWith("/")) set(arg)
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
