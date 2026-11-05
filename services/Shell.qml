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
    readonly property var settingsPages: ["general", "appearance", "notifications", "power", "weather", "about"]
    property bool widgetsPinned: false   // right widgets panel pinned open (Mod+A)
    property int  widgetsTab: 0          // 0 system, 1 weather, 2 focus
    // Each screen has its own widgets panel; it reports here whether it is on screen.
    property var shownOn: ({})           // screen name -> bool
    readonly property bool widgetsShown: Object.values(shownOn).some(v => v === true)
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
        if (name === "widgets") widgetsPinned = true
        else if (name === "settings") openSettings()
        else if (name === "appearance") openSettings("appearance")
        else overlay = name
    }
    function close()      { overlay = "" }
    function toggle(name) {
        if (name === "widgets") widgetsPinned = !widgetsPinned
        else if (name === "settings") { if (settingsOpen) settingsOpen = false; else openSettings() }
        else if (name === "appearance") { if (settingsOpen && settingsPage === "appearance") settingsOpen = false; else openSettings("appearance") }
        else overlay = (overlay === name) ? "" : name
    }
}
