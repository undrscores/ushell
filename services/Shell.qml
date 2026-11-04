pragma Singleton
import Quickshell
import QtQuick

// Tracks which overlay is open (only one at a time) and exposes it over IPC:
//   qs ipc call shell toggle launcher
Singleton {
    id: root
    property string overlay: ""

    function open(name)   { overlay = name }
    function close()      { overlay = "" }
    function toggle(name) { overlay = (overlay === name) ? "" : name }
}
