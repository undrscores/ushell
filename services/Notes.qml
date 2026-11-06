pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// One scratch note, saved to notes.txt in StateDir.dir as you type (shown in the widgets panel's Focus tab).
Singleton {
    id: root
    property string text: ""
    property bool ready: false           // false until the file has been read: typing before that would overwrite it

    function edit(t) {
        if (!ready || t === text) return
        text = t
        saveTimer.restart()
    }

    Timer { id: saveTimer; interval: 600; onTriggered: file.setText(root.text) }
    Component.onDestruction: if (saveTimer.running) file.setText(root.text)     // a reload within 600 ms of typing must not lose it

    FileView {
        id: file
        path: StateDir.ready ? StateDir.dir + "/notes.txt" : ""
        watchChanges: false
        printErrors: false
        onLoaded: { root.text = file.text(); root.ready = true }
        onLoadFailed: root.ready = true      // no file yet
    }
}
