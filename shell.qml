//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import "modules/bar"
import "modules/leftbar"
import "modules/widgets"
import "modules/launcher"
import "modules/quicksettings"
import "modules/calendar"
import "modules/media"
import "modules/power"
import "services"

ShellRoot {
    // singletons are created lazily; touch these so clipboard watching and saved prefs start with the shell
    readonly property var warm: [Clipboard.items.length, Prefs.topAutoHide]

    Bar {}
    LeftBar {}
    Widgets {}
    Launcher { id: launcher }
    QuickSettings {}
    CalendarMenu {}
    MediaMenu {}
    PowerMenu {}

    // qs ipc call launcher query "m "   (open the launcher pre-filled, e.g. for a music-search keybind)
    IpcHandler {
        target: "launcher"
        function query(text: string): void { launcher.query(text) }
    }

    // qs ipc call shell toggle <launcher|quicksettings|calendar|media|power|widgets>
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name) }
        function open(name: string): void   { Shell.open(name) }
        function close(): void              { Shell.close() }
        // qs ipc call shell autohide <top|left>   toggle always-visible vs auto-hide (saved)
        function autohide(name: string): void { Prefs.toggle(name) }
        // qs ipc call shell tab <0|1|2>   open the widgets panel on a tab
        // qs ipc call shell lefttab <0|1>   select the left sidebar tab (apps / clipboard)
        function lefttab(index: int): void   { Shell.leftTab = index }
        function tab(index: int): void      { Shell.widgetsTab = index; Shell.widgetsPinned = true }
    }
}
