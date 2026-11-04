pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// User settings, edited from the Settings menu and saved to
// ~/.local/state/ushell/prefs.json.
Singleton {
    id: root
    property bool topAutoHide: true      // false = top pill always visible (reserves space)
    property bool leftAutoHide: true     // false = left dock always visible (reserves space)
    property bool weatherMetric: true
    property string weatherCity: ""      // empty = locate by IP address
    property string themeMode: "dark"    // dark | light
    property string accent: "mauve"      // see config/palette.js

    function set(key, value) {
        if (root[key] === value || !StateDir.ready) return
        root[key] = value
        file.setText(JSON.stringify({
            topAutoHide: topAutoHide, leftAutoHide: leftAutoHide,
            weatherMetric: weatherMetric, weatherCity: weatherCity,
            themeMode: themeMode, accent: accent
        }))
    }

    FileView {
        id: file
        path: StateDir.ready ? StateDir.dir + "/prefs.json" : ""
        watchChanges: false
        onLoaded: {
            try {
                const j = JSON.parse(file.text())
                for (const k of ["topAutoHide", "leftAutoHide", "weatherMetric"])
                    if (typeof j[k] === "boolean") root[k] = j[k]
                if (typeof j.weatherCity === "string") root.weatherCity = j.weatherCity
                if (j.themeMode === "dark" || j.themeMode === "light") root.themeMode = j.themeMode
                if (typeof j.accent === "string") root.accent = j.accent      // unknown names fall back to mauve in palette.js
            } catch (e) {}
        }
    }
}
