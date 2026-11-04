pragma Singleton
import Quickshell
import QtQuick

// User-editable settings.
Singleton {
    // Desktop-entry names shown in the left dock (matched loosely, missing ones are skipped).
    // Weather tab. Empty city = locate by IP address (via ipapi.co); otherwise geocode the name (Open-Meteo).
    readonly property string weatherCity: ""
    readonly property bool weatherMetric: true

    readonly property var pinnedApps: ["firefox", "alacritty", "keepassxc", "mpv"]
}
