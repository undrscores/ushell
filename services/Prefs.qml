pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// User settings, edited from the Settings menu and saved to
// ~/.local/state/quickshell-config/prefs.json.
Singleton {
    id: root
    property bool topAutoHide: true      // false = top pill always visible (reserves space)
    property bool leftAutoHide: true     // false = left dock always visible (reserves space)
    property bool weatherMetric: true
    property string weatherCity: ""      // empty = locate by IP address

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell-config"

    function set(key, value) {
        if (root[key] === value) return
        root[key] = value
        file.setText(JSON.stringify({
            topAutoHide: topAutoHide, leftAutoHide: leftAutoHide,
            weatherMetric: weatherMetric, weatherCity: weatherCity
        }))
    }

    FileView {
        id: file
        path: root.dir + "/prefs.json"
        watchChanges: false
        onLoaded: {
            try {
                const j = JSON.parse(file.text())
                for (const k of ["topAutoHide", "leftAutoHide", "weatherMetric"])
                    if (typeof j[k] === "boolean") root[k] = j[k]
                if (typeof j.weatherCity === "string") root.weatherCity = j.weatherCity
            } catch (e) {}
        }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])
}
