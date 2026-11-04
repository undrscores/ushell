pragma Singleton
import Quickshell
import QtQuick

// Tracks which overlay is open (only one at a time) and exposes it over IPC:
//   qs ipc call shell toggle launcher
Singleton {
    id: root
    property string overlay: ""          // one dropdown/overlay at a time
    property bool widgetsPinned: false   // right widgets panel pinned open (Mod+A)
    property int  widgetsTab: 0          // 0 media, 1 system, 2 weather
    property bool widgetsShown: false    // set by the widgets panel while visible

    function open(name)   { if (name === "widgets") widgetsPinned = true; else overlay = name }
    function close()      { overlay = "" }
    function toggle(name) {
        if (name === "widgets") widgetsPinned = !widgetsPinned
        else overlay = (overlay === name) ? "" : name
    }
}
