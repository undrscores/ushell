pragma Singleton
import Quickshell
import QtQuick
import "../config"

// System and shell actions, shared by the launcher and the power menu.
// Destructive ones are armed by the first trigger and only run on a second one.
Singleton {
    id: root
    property string armed: ""            // id of the destructive action waiting for confirmation

    function disarm() { armed = ""; disarmTimer.stop() }

    // Runs the action, or arms it first if it's destructive. Returns true if it actually ran.
    function trigger(def) {
        if (def.danger === true && armed !== def.id) { armed = def.id; disarmTimer.restart(); return false }
        disarm()
        def.run()
        return true
    }
    Timer { id: disarmTimer; interval: 4000; onTriggered: root.armed = "" }

    function widgetsTab(n) { Shell.widgetsTab = n; Shell.widgetsPinned = true }

    // { id, title, glyph, words, run, danger?, power?, label? }   (power ones also show in the power menu)
    readonly property var defs: [
        { id: "lock", power: true, label: "Lock",     title: "Lock screen",     glyph: "", words: "lock screen secure",
          run: () => Lock.lock() },
        { id: "sleep", power: true, label: "Suspend",    title: "Sleep",           glyph: "", words: "suspend sleep",
          run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { id: "logout", power: true, label: "Log out",   title: "Log out",         glyph: "", words: "logout sign out exit niri", danger: true,
          run: () => Quickshell.execDetached(["niri", "msg", "action", "quit", "-s"]) },
        { id: "reboot", power: true, label: "Reboot",   title: "Restart",         glyph: "", words: "reboot restart", danger: true,
          run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { id: "shutdown", power: true, label: "Shut down", title: "Shut down",       glyph: "", words: "poweroff power off shutdown", danger: true,
          run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        { id: "mute",     title: "Toggle mute",     glyph: "", words: "mute unmute sound volume audio",
          run: () => Audio.toggleMute() },
        { id: "notifications", title: "Notification history", glyph: "\uf0f3", words: "notifications history alerts messages bell",
          run: () => Shell.open("notifications") },
        { id: "dnd", title: "Toggle Do Not Disturb", glyph: "\uf1f6", words: "do not disturb dnd silence quiet notifications popups mute",
          run: () => Notifications.toggleDnd() },
        { id: "clear-notifications", title: "Clear notifications", glyph: "\uf014", words: "clear dismiss delete notifications history",
          run: () => Notifications.clear() },
        { id: "media",  title: "Media player",    glyph: "", words: "music player now playing cava",
          run: () => Shell.open("media") },
        { id: "w-system", title: "System monitor",  glyph: "", words: "cpu gpu memory ram disk stats performance usage widgets",
          run: () => root.widgetsTab(0) },
        { id: "w-focus",   title: "Focus timer and note", glyph: "\uf017", words: "timer pomodoro countdown notes scratch widgets",
          run: () => root.widgetsTab(2) },
        { id: "w-weather", title: "Weather",        glyph: "", words: "forecast temperature rain sun widgets",
          run: () => root.widgetsTab(1) },
        { id: "network", title: "Network and Wi-Fi", glyph: "\uf1eb", words: "network wifi wi-fi internet connection ethernet wireless online",
          run: () => Shell.open("network") },
        { id: "keep-awake", title: "Toggle keep awake", glyph: "\uf0f4", words: "keep awake caffeine idle inhibit sleep lock screen off stay",
          run: () => Idle.toggle() },
        { id: "clipboard", title: "Clipboard history", glyph: "\uf0ea", words: "copy paste history clipboard",
          run: () => Shell.open("clipboard") },
        { id: "appearance", title: "Appearance", glyph: "\uf1fc", words: "appearance theme colors accent dark light wallpaper look style",
          run: () => Shell.open("appearance") },
        { id: "wallpapers", title: "Wallpapers", glyph: "\uf03e", words: "wallpaper background picture image theme colors choose",
          run: () => Shell.open("wallpapers") },
        { id: "wallpaper-next", title: "Next wallpaper", glyph: "\uf051", words: "wallpaper background change cycle",
          run: () => Wallpapers.next() },
        { id: "wallpaper-random", title: "Random wallpaper", glyph: "\uf074", words: "wallpaper background shuffle surprise",
          run: () => Wallpapers.random() },
        { id: "theme", title: "Toggle light / dark theme", glyph: "\uf186", words: "theme dark light mode night day appearance",
          run: () => Prefs.set("themeMode", Prefs.themeMode === "dark" ? "light" : "dark") },
        { id: "settings", title: "Settings", glyph: "\uf013", words: "settings preferences config autohide weather",
          run: () => Shell.open("settings") },
        { id: "sound",    title: "Sound settings",  glyph: "", words: "volume microphone output device audio quick settings",
          run: () => Shell.open("quicksettings") },
        { id: "reload",   title: "Reload shell",    glyph: "", words: "restart quickshell reload",
          run: () => Quickshell.reload(false) }
    ]

    readonly property var power: defs.filter(d => d.power === true)
}
