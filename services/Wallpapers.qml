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

    // ── choosing ────────────────────────────────────────────────────────────
    function set(path) { failed = ""; Prefs.set("wallpaper", path) }
    function off() { Prefs.set("wallpaper", "") }

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
    function command(arg) {
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
                if (j && typeof j.hue === "number") { root.hue = j.hue; root.sat = j.sat ?? 0.5; root.colorsOk = true; root.colorError = "" }
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
