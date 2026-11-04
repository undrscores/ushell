pragma Singleton
import Quickshell
import QtQuick

// User-editable settings.
Singleton {
    // Desktop-entry names shown in the left dock (matched loosely, missing ones are skipped).
    readonly property var pinnedApps: ["firefox", "alacritty", "keepassxc", "mpv"]

    // Terminal for launcher jobs that need one (package install/remove): runs `<terminal> -e bash -c ...`.
    readonly property string terminal: "alacritty"

    // Command that locks the screen.
    readonly property var lockCommand: ["swaylock", "-f"]

    // Web search for the launcher ("g " prefix and the no-results fallback); the query is appended URL-encoded.
    readonly property string searchUrl: "https://duckduckgo.com/?q="
}
