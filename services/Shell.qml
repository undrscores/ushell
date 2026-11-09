pragma Singleton
import Quickshell
import QtQuick

// Tracks which overlay is open (only one at a time) and exposes it over IPC:
//   qs ipc call shell toggle launcher
Singleton {
    id: root
    property string overlay: ""          // one dropdown/overlay at a time
    // The settings window is a window of its own (not an overlay); `settingsPage` is the section it shows.
    property bool settingsOpen: false
    property string settingsPage: "general"
    readonly property var settingsPages: ["general", "appearance", "notifications", "sound", "display", "canvas", "power", "weather", "about"]
    property bool widgetsPinned: false   // right widgets panel pinned open (Mod+A)
    property int  widgetsTab: 0          // 0 control, 1 system, 2 weather, 3 focus
    // Open the panel on a tab for a few seconds, then let it hide again (IPC `shell tab N`). A panel that was
    // already pinned open (Mod+A) stays pinned.
    property bool widgetsPeek: false
    function peekWidgets(tab) {
        widgetsTab = tab
        if (widgetsPinned && !widgetsPeek) return
        widgetsPeek = true
        widgetsPinned = true
        peekTimer.restart()
    }
    Timer { id: peekTimer; interval: 4000; onTriggered: { root.widgetsPeek = false; root.widgetsPinned = false } }   // hovering keeps it open anyway
    // Each screen has its own widgets panel; it reports here whether it is on screen.
    property var shownOn: ({})           // screen name -> bool
    readonly property bool widgetsShown: Object.values(shownOn).some(v => v === true)
    // The full player grows out of the now-playing capsule (bottom left). `mediaPinned` holds it open
    // (launcher, `qs ipc call shell toggle media`); each screen's capsule reports whether it is showing the full player.
    property bool mediaPinned: false
    property var fullOn: ({})
    readonly property bool mediaFull: Object.values(fullOn).some(v => v === true)
    function setMediaFull(screenName, on) {
        if ((fullOn[screenName] === true) === on) return
        const m = Object.assign({}, fullOn)
        m[screenName] = on
        fullOn = m
    }
    function setWidgetsShown(screenName, shown) {
        if ((shownOn[screenName] === true) === shown) return
        const m = Object.assign({}, shownOn)
        m[screenName] = shown
        shownOn = m
    }

    // "settings" opens the settings window; "appearance" is a shortcut to its Appearance section.
    function openSettings(page) {
        if (page !== undefined && settingsPages.includes(page)) settingsPage = page
        overlay = ""
        settingsOpen = true
    }
    function open(name) {
        if (name === "widgets") { widgetsPeek = false; peekTimer.stop(); widgetsPinned = true }
        else if (name === "media") mediaPinned = true
        else if (name === "settings") openSettings()
        else if (name === "appearance") openSettings("appearance")
        else if (name === "display") openSettings("display")
        else if (name === "sound") openSettings("sound")
        else overlay = name
    }
    function close()      { overlay = "" }
    function toggle(name) {
        if (name === "widgets") { widgetsPeek = false; peekTimer.stop(); widgetsPinned = !widgetsPinned }
        else if (name === "media") mediaPinned = !mediaPinned
        else if (name === "settings") { if (settingsOpen) settingsOpen = false; else openSettings() }
        else if (name === "appearance") { if (settingsOpen && settingsPage === "appearance") settingsOpen = false; else openSettings("appearance") }
        else if (name === "display") { if (settingsOpen && settingsPage === "display") settingsOpen = false; else openSettings("display") }
        else if (name === "sound") { if (settingsOpen && settingsPage === "sound") settingsOpen = false; else openSettings("sound") }
        else overlay = (overlay === name) ? "" : name
    }
}
