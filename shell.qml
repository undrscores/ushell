//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import "modules/bar"
import "modules/launcher"
import "services"

ShellRoot {
    Bar {}
    Launcher {}

    // qs ipc call shell toggle launcher
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name) }
        function open(name: string): void   { Shell.open(name) }
        function close(): void              { Shell.close() }
    }
}
