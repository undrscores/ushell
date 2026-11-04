pragma Singleton
import Quickshell
import QtQuick

// Single source of truth for the look & feel. Every module reads from here.
Singleton {
    // Palette (dark, mauve accent)
    readonly property color bg:        "#1e1e2e"
    readonly property color bgAlt:     "#181825"
    readonly property color surface:   "#313244"
    readonly property color surfaceHi: "#45475a"
    readonly property color fg:        "#cdd6f4"
    readonly property color fgDim:     "#7f849c"
    readonly property color accent:    "#cba6f7"
    readonly property color accentFg:  "#1e1e2e"
    readonly property color danger:    "#f38ba8"
    readonly property color ok:        "#a6e3a1"

    // Shape & spacing
    readonly property int radius:      14
    readonly property int radiusSmall: 8
    readonly property int spacing:     8
    readonly property int margin:      8
    readonly property int barHeight:   38

    // Typography
    readonly property string font: "Sans"
    readonly property int fontSize: 13

    // Motion
    readonly property int animFast:   120
    readonly property int animNormal: 220
    readonly property int animSlow:   380
    readonly property int easing:     Easing.OutCubic
}
