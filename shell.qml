//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "modules/leftbar"
import "modules/widgets"
import "modules/launcher"
import "modules/quicksettings"
import "modules/calendar"
import "modules/clipboard"
import "modules/settings"
import "modules/media"
import "modules/power"
import "services"
import "config"

ShellRoot {
    // singletons are created lazily; touch the clipboard so its history watcher starts with the shell
    readonly property var warm: [Clipboard.items.length]

    // the saved theme choice drives the Theme singleton
    Binding { target: Theme; property: "mode"; value: Prefs.themeMode }
    Binding { target: Theme; property: "accentName"; value: Prefs.accent }

    Bar {}
    LeftBar {}
    Widgets {}
    Launcher { id: launcher }
    QuickSettings {}
    CalendarMenu {}
    MediaMenu {}
    ClipboardMenu {}
    SettingsMenu {}
    PowerMenu {}

    // qs ipc call launcher query "m "   (open the launcher pre-filled, e.g. for a music-search keybind)
    IpcHandler {
        target: "launcher"
        function query(text: string): void { launcher.query(text) }
    }

    // qs ipc call shell toggle <launcher|quicksettings|calendar|media|clipboard|settings|power|widgets>
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name) }
        function open(name: string): void   { Shell.open(name) }
        function close(): void              { Shell.close() }
        // qs ipc call shell tab <0|1|2>   open the widgets panel on a tab
        // qs ipc call shell brightness <+N|-N>   change brightness of all monitors by N percent
        function brightness(delta: int): void { Brightness.step(delta) }
        function tab(index: int): void      { Shell.widgetsTab = index; Shell.widgetsPinned = true }
        // qs ipc call shell theme <dark|light|toggle>   (e.g. from a day/night timer)
        function theme(mode: string): void {
            if (mode === "toggle") Prefs.set("themeMode", Prefs.themeMode === "dark" ? "light" : "dark")
            else if (mode === "dark" || mode === "light") Prefs.set("themeMode", mode)
        }
    }
}
