pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "config.js" as Rules

// User settings. The values below are the defaults; to change them, create
//   ~/.config/ushell/config.json        (see config.example.json in the shell's folder)
// with just the keys you want. It reloads as soon as you save it. A key that is missing or invalid
// keeps its default, and a warning shows up in `qs log`.
Singleton {
    id: root

    readonly property var defaults: ({
        pinnedApps: ["firefox", "alacritty", "keepassxc", "mpv"],
        terminal: "alacritty",
        nativeLock: true,
        lockCommand: ["swaylock", "-f"],
        searchUrl: "https://duckduckgo.com/?q=",
        searchShortcuts: { yt: "https://www.youtube.com/results?search_query=", gh: "https://github.com/search?q=",
                           w: "https://en.wikipedia.org/w/index.php?search=", so: "https://stackoverflow.com/search?q=",
                           maps: "https://www.openstreetmap.org/search?query=" },
        glassOpacity: 1.0,
        maxVolume: 1.0,
        wallpaperDir: "~/wallpapers",
        frameSize: 8,
        recordingDir: "~/Videos/Recordings",
        screenshotDir: "~/Pictures/Screenshots",
        calendarPaths: ["~/.local/share/ushell/calendar", "~/.local/share/calendars"]
    })

    // Desktop-entry names shown in the left dock (matched loosely, missing ones are skipped).
    property var pinnedApps: defaults.pinnedApps

    // Terminal for launcher jobs that need one (package install/remove): runs `<terminal> -e bash -c ...`.
    property string terminal: defaults.terminal

    // true = ushell's own lock screen (password checked with PAM); false = run lockCommand instead.
    property bool nativeLock: defaults.nativeLock

    // Command that locks the screen when nativeLock is false: the program and its arguments.
    property var lockCommand: defaults.lockCommand

    // Web search for the launcher ("g " prefix); the query is appended URL-encoded.
    property string searchUrl: defaults.searchUrl

    // Launcher web shortcuts: typing "yt cats" searches that URL (the query is appended URL-encoded).
    // Setting this in config.json replaces the whole list.
    property var searchShortcuts: defaults.searchShortcuts

    // How opaque panels are: 1 = solid, down to 0.5 = see-through.
    property real glassOpacity: defaults.glassOpacity

    // Loudest the volume sliders and the bar's scroll wheel go: 1 = 100%, up to 1.5 (amplified, can distort).
    property real maxVolume: defaults.maxVolume

    // Folder the wallpaper picker lists (pictures up to one folder deep).
    property string wallpaperDir: defaults.wallpaperDir

    // How thick the frame around the screen edges is, in pixels (it is switched on and off in Settings). Keep niri's
    // `gaps` at least this large so windows sit inside it.
    property int frameSize: defaults.frameSize

    // Where screen recordings are saved (screenshots go to screenshotDir).
    property string recordingDir: defaults.recordingDir
    property string screenshotDir: defaults.screenshotDir

    // .ics files and folders (searched recursively) the calendar shows events from. A vdirsyncer or khal
    // calendar folder works; so does a single exported file.
    property var calendarPaths: defaults.calendarPaths

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ushell/config.json"

    // Validate the file and apply every key that differs from what is set now.
    function apply(text) {
        const r = Rules.parse(text, defaults)
        for (const w of r.warnings) console.warn("ushell config.json: " + w)
        for (const k of Object.keys(defaults))
            if (JSON.stringify(root[k]) !== JSON.stringify(r.values[k])) root[k] = r.values[k]
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onLoaded: root.apply(file.text())
        onFileChanged: reload()
        printErrors: false                  // a missing file is the normal case, not something to warn about
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) console.warn("ushell config.json: cannot read " + root.path + " (using defaults)")
            root.apply("{}")
        }
    }
}
