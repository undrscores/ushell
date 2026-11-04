pragma Singleton
import Quickshell
import QtQuick
import "palette.js" as Palette

// Single source of truth for the look & feel. Every module reads from here.
Singleton {
    // Which palette is in use. Set from the saved preferences (see the Binding items in shell.qml);
    // the colours themselves live in palette.js.
    property string mode: "dark"          // dark | light
    property string accentName: "mauve"
    // Accent taken from the wallpaper (hue in degrees, -1 = not in use); set from Wallpapers via shell.qml.
    property real wallHue: -1
    property real wallSat: 0
    readonly property var pal: Palette.make(mode, accentName, wallHue >= 0 ? { hue: wallHue, sat: wallSat } : null)

    readonly property color bg:        pal.bg
    readonly property color surface:   pal.surface
    readonly property color surfaceHi: pal.surfaceHi
    readonly property color fg:        pal.fg
    readonly property color fgDim:     pal.fgDim
    readonly property color accent:    pal.accent
    readonly property color accent2:   pal.accent2
    readonly property color accentFg:  pal.accentFg       // text on top of the accent colour
    readonly property color danger:    pal.danger
    readonly property color ok:        pal.ok
    readonly property color dangerSoft: Qt.rgba(danger.r, danger.g, danger.b, 0.26)   // armed / hovered destructive buttons

    // Glass surfaces (shared by every panel). Overlays are white on dark and ink on light.
    readonly property color glass:  Qt.rgba(bg.r, bg.g, bg.b, Config.glassOpacity)
    readonly property color ink:    pal.ink
    readonly property color line:   Qt.rgba(ink.r, ink.g, ink.b, 0.08)
    readonly property color hover:  Qt.rgba(ink.r, ink.g, ink.b, 0.09)
    readonly property color tint:   Qt.rgba(ink.r, ink.g, ink.b, 0.05)
    readonly property color sheen:  Qt.rgba(1, 1, 1, pal.sheen)     // soft highlight along a panel's top edge
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.18)

    // Shape & spacing
    readonly property int radius:      14
    readonly property int radiusSmall: 8
    readonly property int margin:      8
    readonly property int barHeight:   38
    readonly property int dockWidth:   68      // left dock; the clipboard flyout opens beside it

    // Typography
    readonly property string font: "Sans"
    readonly property int fontSize: 13
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int iconSize: 16

    // Motion
    readonly property int animFast:   120
    readonly property int animNormal: 220
    readonly property int animSlow:   380
    readonly property int easing:     Easing.OutCubic
}
