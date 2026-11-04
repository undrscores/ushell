//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import "modules/bar"
import "modules/launcher"
import "modules/quicksettings"
import "modules/sidebar"
import "modules/power"
import "services"

ShellRoot {
    Bar {}
    Launcher {}
    QuickSettings {}
    Sidebar {}
    PowerMenu {}

    // qs ipc call shell toggle <launcher|quicksettings|sidebar|power>
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name) }
        function open(name: string): void   { Shell.open(name) }
        function close(): void              { Shell.close() }
    }
}
