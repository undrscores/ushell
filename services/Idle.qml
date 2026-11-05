pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// "Keep awake": while on, ushell does not lock or switch the screens off on idle. It is held by a
// systemd idle inhibitor (so other idle handlers, and the compositor, respect it too). Off after a reload
// or restart of the shell on purpose: nobody wants to find it still on a week later.
Singleton {
    id: root
    property bool keepAwake: false
    function toggle() { keepAwake = !keepAwake }

    Process {
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle", "--who=ushell", "--why=Keep awake", "--mode=block", "sleep", "infinity"]
    }
}
