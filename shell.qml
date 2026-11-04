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
    Bar {}
    LeftBar {}
    Widgets {}
    Launcher {}
    QuickSettings {}
    CalendarMenu {}
    MediaMenu {}
    PowerMenu {}

    // qs ipc call shell toggle <launcher|quicksettings|calendar|media|power|widgets>
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name) }
        function open(name: string): void   { Shell.open(name) }
        function close(): void              { Shell.close() }
        // qs ipc call shell tab <0|1|2>   open the widgets panel on a tab
        function tab(index: int): void      { Shell.widgetsTab = index; Shell.widgetsPinned = true }
    }
}
