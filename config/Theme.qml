pragma Singleton
import Quickshell
import QtQuick
import "palette.js" as Palette

// Single source of truth for the look & feel. Every module reads from here.
Singleton {
    id: root
    // Which palette is in use. Set from the saved preferences (see the Binding items in shell.qml);
    // the colours themselves live in palette.js.
    property string mode: "dark"          // dark | light
    property string accentName: "mauve"
    // Accent taken from the wallpaper (hue in degrees, -1 = not in use); set from Wallpapers via shell.qml.
    property real wallHue: -1
    property real wallSat: 0
    property real wallHue2: -1          // the wallpaper's second colour (-1 = none): used for accent2
    property real wallSat2: 0
    readonly property var pal: Palette.make(mode, accentName, wallHue >= 0 ? ({ hue: wallHue, sat: wallSat, hue2: wallHue2 >= 0 ? wallHue2 : undefined, sat2: wallSat2 }) : null)

    property color bg:        pal.bg
    property color surface:   pal.surface
    property color surfaceHi: pal.surfaceHi
    property color fg:        pal.fg
    property color fgDim:     pal.fgDim
    property color accent:    pal.accent
    property color accent2:   pal.accent2
    property color accentFg:  pal.accentFg       // text on top of the accent colour
    readonly property color danger:    pal.danger
    readonly property color ok:        pal.ok
    readonly property color dangerSoft: Qt.rgba(danger.r, danger.g, danger.b, 0.26)   // armed / hovered destructive buttons

    // Glass surfaces (shared by every panel). Overlays are white on dark and ink on light.
    readonly property color glass:  Qt.rgba(bg.r, bg.g, bg.b, Config.glassOpacity)
    property color ink:    pal.ink
    readonly property color line:   Qt.rgba(ink.r, ink.g, ink.b, 0.08)
    readonly property color hover:  Qt.rgba(ink.r, ink.g, ink.b, 0.09)
    readonly property color tint:   Qt.rgba(ink.r, ink.g, ink.b, 0.05)
    readonly property color sheen:  Qt.rgba(1, 1, 1, pal.sheen)     // soft highlight along a panel's top edge
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.18)

    // Switching theme (dark/light, accent, wallpaper colours) fades every colour instead of snapping.
    // Everything below (line, tint, glass ...) is computed from these, so it fades along with them.
    // Off for the first moments so the saved theme doesn't visibly fade in from the defaults at login.
    property bool fading: false
    Timer { interval: 1500; running: true; onTriggered: root.fading = true }
    Behavior on bg        { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on surface   { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on surfaceHi { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on fg        { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on fgDim     { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on accent    { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on accent2   { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on accentFg  { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }
    Behavior on ink       { enabled: root.fading; ColorAnimation { duration: root.animFade; easing.type: Easing.InOutQuad } }

    // Shape & spacing
    readonly property int radius:      16
    readonly property int radiusSmall: 10
    readonly property int radiusLarge: radius + 4     // panels and cards
    readonly property int margin:      8
    readonly property int frame:       Config.frame ? Config.frameSize : 0     // screen-edge frame thickness (0 = off)
    readonly property int frameRadius: 22                                      // rounding of the frame's inner corners
    readonly property int inset:       frame + margin                          // where floating panels sit from the screen edge
    readonly property int barHeight:   38
    readonly property int dockWidth:   68      // left dock; the clipboard flyout opens beside it

    // Typography
    readonly property string font: "JetBrains Mono"      // install jetbrains-mono-fonts; Qt falls back to the default sans without it
    readonly property int fontSize: 13       // JetBrains Mono is wide: 13 here sets about as wide as 14 in a proportional font
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int iconSize: 17

    // Motion
    readonly property int animFast:   120
    readonly property int animNormal: 220
    readonly property int animSlow:   380
    readonly property int animFade:   450      // theme changes
    readonly property int easing:     Easing.OutCubic
    // Spring presets for Spring.qml (spring = stiffness, damping = how fast the wobble dies)
    readonly property var springs: ({
        popIn:  { spring: 3.4, damping: 0.24 },
        popOut: { spring: 6.0, damping: 0.80 },
        settle: { spring: 3.6, damping: 0.34 },
        glide:  { spring: 4.5, damping: 0.32 },
        snap:   { spring: 6.0, damping: 0.30 }
    })
}
