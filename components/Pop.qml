import QtQuick
import "../config"

// A quick pop with a little overshoot, for things appearing or selecting. Usage:
//   Behavior on scale { Pop {} }        Pop { overshoot: 3 }  for a bigger kick, duration to slow it down
NumberAnimation {
    property real overshoot: 2.5
    duration: Theme.animPop
    easing.type: Easing.OutBack
    easing.overshoot: overshoot
}
