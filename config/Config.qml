pragma Singleton
import Quickshell
import QtQuick

// User-editable settings.
Singleton {
    // Desktop-entry names shown in the left dock (matched loosely, missing ones are skipped).
    readonly property var pinnedApps: ["firefox", "alacritty", "keepassxc", "mpv"]
}
