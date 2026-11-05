import QtQuick
import "../config"

// A SpringAnimation driven by the shared presets in Theme.springs, so motion feels the same everywhere.
//   popIn / popOut  panels and cards appearing (bouncy) and leaving (tight)
//   settle          size changes
//   glide           sliding indicators and selections
//   snap            small controls (switches, dock markers)
// Usage:  Behavior on scale { Spring { preset: open ? "popIn" : "popOut"; epsilon: 0.002 } }
SpringAnimation {
    property string preset: "settle"
    readonly property var p: Theme.springs[preset] || Theme.springs.settle
    spring: p.spring
    damping: p.damping
    epsilon: 0.3
}
