pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Settings that should survive restarts (saved to ~/.local/state/quickshell-config/prefs.json).
Singleton {
    id: root
    property bool topAutoHide: true
    property bool leftAutoHide: true

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell-config"

    function toggle(name) {
        if (name === "top") topAutoHide = !topAutoHide
        else if (name === "left") leftAutoHide = !leftAutoHide
        else return
        file.setText(JSON.stringify({ topAutoHide: topAutoHide, leftAutoHide: leftAutoHide }))
    }

    FileView {
        id: file
        path: root.dir + "/prefs.json"
        watchChanges: false
        onLoaded: {
            try {
                const j = JSON.parse(file.text())
                if (typeof j.topAutoHide === "boolean") root.topAutoHide = j.topAutoHide
                if (typeof j.leftAutoHide === "boolean") root.leftAutoHide = j.leftAutoHide
            } catch (e) {}
        }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])
}
