import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services"

// Idle handling: lock after Prefs.idleLockMin idle minutes, turn the screens off after Prefs.idleOffMin
// (0 = never for both), and "keep awake" (Idle.keepAwake) which holds back both. Uses the compositor's
// idle notification, so anything that inhibits idle (a video player, a browser playing video) also holds
// these back.
Scope {
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
        onIsIdleChanged: Quickshell.execDetached(["niri", "msg", "action", isIdle ? "power-off-monitors" : "power-on-monitors"])
    }
}
