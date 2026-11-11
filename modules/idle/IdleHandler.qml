import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services"

// Idle handling: lock after Prefs.idleLockMin idle minutes, turn the screens off after Prefs.idleOffMin
// (0 = never for both), and "keep awake" (Idle.keepAwake) which holds back both. Uses the compositor's
// idle notification, so anything that inhibits idle (a video player, a browser playing video) also holds
// these back.
// Before the first of those fires the screens dim for Prefs.idleDimSec seconds (0 = no dimming), as a warning:
// any key or mouse move brings the screen back.
Scope {
    id: root

    // seconds of idling until the first of lock / screens-off fires (0 = neither is set)
    readonly property int firstSec: {
        const l = Prefs.idleLockMin * 60, o = Prefs.idleOffMin * 60
        return l > 0 && o > 0 ? Math.min(l, o) : Math.max(l, o)
    }
    // the dim starts this long before that, but never within the first 10 seconds of idling
    readonly property int dimAfterSec: Math.max(10, root.firstSec - Prefs.idleDimSec)

    IdleMonitor {
        enabled: Prefs.idleLockMin > 0 && !Idle.keepAwake && !Lock.locked
        timeout: Math.max(1, Prefs.idleLockMin * 60)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    IdleMonitor {
        enabled: Prefs.idleOffMin > 0 && !Idle.keepAwake
        timeout: Math.max(1, Prefs.idleOffMin * 60)
        respectInhibitors: true
        onIsIdleChanged: Wm.screensOff(isIdle)
    }
    IdleMonitor {
        id: dimMonitor
        enabled: Prefs.idleDimSec > 0 && root.firstSec > 0 && root.dimAfterSec < root.firstSec && !Idle.keepAwake && !Lock.locked
        timeout: root.dimAfterSec
        respectInhibitors: true
    }

    // The dimming: a black layer over every screen that lets all input through.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}                                  // empty input region: clicks and keys go to the windows below
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "ushell-idle-dim"
            visible: veil.opacity > 0.01

            Rectangle {
                id: veil
                anchors.fill: parent
                color: "black"
                opacity: dimMonitor.enabled && dimMonitor.isIdle ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: dimMonitor.isIdle ? 1500 : 150; easing.type: Easing.OutQuad } }
            }
        }
    }
}
