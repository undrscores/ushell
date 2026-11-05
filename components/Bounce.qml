import QtQuick
import "../config"

// Springy overshoot for hover / press feedback (scale). Usage:  Behavior on scale { Bounce {} }
NumberAnimation {
    duration: Theme.animBounce
    easing.type: Easing.OutElastic
    easing.amplitude: 1.1
    easing.period: 0.45
}
