//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "modules/widgets"
import "modules/launcher"
import "modules/clipboard"
import "modules/settings"
import "modules/bluetooth"
import "modules/power"
import "modules/wallpaper"
import "modules/notifications"
import "modules/osd"
import "modules/network"
import "modules/lock"
import "modules/idle"
import "modules/frame"
import "modules/capsule"
import "modules/radial"
import "modules/capture"
import "modules/calendar"
import "modules/switcher"
import "modules/minimap"
import "modules/polkit"
import "services"
import "config"

ShellRoot {
    // singletons are created lazily; touch the clipboard and the notification daemon so they start with the shell
    readonly property var warm: [Clipboard.items.length, Notifications.count, LockKeys.seen, Power.hasBattery, Capture.canRecord, Schedule.day, Auth.registered]

    // the saved theme choice drives the Theme singleton
    Binding { target: Theme; property: "mode"; value: Prefs.themeMode }
    Binding { target: Theme; property: "accentName"; value: Prefs.accent }
    Binding { target: Theme; property: "frameOn"; value: Prefs.frame }
    Binding { target: Theme; property: "wallHue"; value: Wallpapers.useColors ? Wallpapers.hue : -1 }
    Binding { target: Theme; property: "wallSat"; value: Wallpapers.sat }
    Binding { target: Theme; property: "wallHue2"; value: Wallpapers.hue2 }
    Binding { target: Theme; property: "wallSat2"; value: Wallpapers.sat2 }

    ThemeExport {}
    Wallpaper {}
    Frame {}
    LockScreen {}
    IdleHandler {}

    Bar {}
    Widgets {}
    MediaCapsule {}
    RadialMenu {}
    Launcher { id: launcher }
    ClipboardMenu {}
    SettingsWindow {}
    BluetoothMenu {}
    PowerMenu {}
    WallpaperPicker {}
    NetworkMenu {}
    NotificationPopups {}
    NotificationsMenu {}
    CaptureMenu {}
    CalendarMenu {}
    WindowSwitcher {}
    MinimapMenu {}
    AuthPrompt {}
    OsdWindow {}

    // qs ipc call launcher query "m "   (open the launcher pre-filled, e.g. for a music-search keybind)
    IpcHandler {
        target: "launcher"
        function query(text: string): void { launcher.query(text) }
    }

    // qs ipc call notifications <toggleDnd | dnd true|false | clear | test | mute APP | unmute APP | status>   (history: qs ipc call shell toggle notifications)
    IpcHandler {
        target: "notifications"
        function toggleDnd(): void { Notifications.toggleDnd() }
        function dnd(on: bool): void { Notifications.setDnd(on) }
        function clear(): void { Notifications.clear() }
        function mute(app: string): void { Notifications.mute(app) }       // popups off for one app (by its name in the popup)
        function unmute(app: string): void { Notifications.unmute(app) }
        function status(): string { return JSON.stringify({ dnd: Notifications.dnd, scheduled: Notifications.scheduled, silent: Notifications.silent, muted: Prefs.mutedApps, count: Notifications.count, popups: Notifications.popups.length }) }
        function test(): void { Notifications.test() }
    }

    // qs ipc call modes <focus true|false | toggleFocus | nightlight true|false | toggleNightlight | status>
    IpcHandler {
        target: "modes"
        function focus(on: bool): void { Prefs.set("focusMode", on) }
        function toggleFocus(): void { Prefs.set("focusMode", !Prefs.focusMode) }
        function nightlight(on: bool): void { Prefs.set("nightLight", on) }
        function toggleNightlight(): void { Prefs.set("nightLight", !Prefs.nightLight) }
        function status(): string { return JSON.stringify({ focus: Prefs.focusMode, nightLight: Prefs.nightLight, available: NightLight.available, running: NightLight.on, failed: NightLight.failed, temp: Prefs.nightTemp }) }
    }

    // qs ipc call timer <start | pause | toggle | reset | set MINUTES | status>   (set takes whole or fractional minutes)
    IpcHandler {
        target: "timer"
        function start(): void { Countdown.start() }
        function pause(): void { Countdown.pause() }
        function toggle(): void { Countdown.toggle() }
        function reset(): void { Countdown.reset() }
        function set(minutes: real): void { Countdown.setMinutes(minutes) }
        function status(): string { return JSON.stringify({ running: Countdown.running, remaining: Math.round(Countdown.remaining), total: Countdown.total }) }
    }

    // qs ipc call network <status | scan | wifi true|false | vpn NAME true|false>
    IpcHandler {
        target: "network"
        function status(): string {
            return JSON.stringify({ available: Network.available, kind: Network.kind, name: Network.name, online: Network.online,
                                    connectivity: Network.connectivity, wifiPresent: Network.wifiPresent, wifiOn: Network.wifiOn,
                                    vpns: Network.vpns.map(v => v.name + (v.active ? " *" : "")),
                                    networks: Network.networks.map(n => n.ssid + " " + n.signal + (n.active ? " *" : "")) })
        }
        function scan(): void { Network.scan() }
        function wifi(on: bool): void { Network.setWifi(on) }
        function vpn(name: string, on: bool): void { Network.setVpn(name, on) }       // a saved VPN / WireGuard profile, by name
    }

    // qs ipc call wm dump     (what the shell sees of uwm: focused output, workspaces, windows; for debugging)
    IpcHandler {
        target: "wm"
        function dump(): string {
            return JSON.stringify({ output: Wm.focusedOutput, workspaces: Wm.workspaces, windows: Wm.windows })
        }
    }

    // qs ipc call keys status     (Caps / Num Lock, keyboard layout, apps recording from a microphone)
    IpcHandler {
        target: "keys"
        function status(): string {
            return JSON.stringify({ caps: LockKeys.caps, num: LockKeys.num, seen: LockKeys.seen, layouts: Wm.layouts, layout: Wm.layoutShort,
                                    micInUse: Audio.micInUse, recorders: Audio.recorderNames })
        }
        function layoutOsd(): void { Osd.showText("layout", Wm.layoutName || "English (US)", true) }
    }

    // qs ipc call capture <region|screen|window|record|recordRegion|stop|toggle|cancel|status>   (screenshots need grim, recording wf-recorder)
    IpcHandler {
        target: "capture"
        function region(): void { Capture.screenshot("region") }
        function screen(): void { Capture.screenshot("screen") }
        function window(): void { Capture.screenshot("window") }
        function record(): void { Capture.record(false) }
        function recordRegion(): void { Capture.record(true) }
        function stop(): void { Capture.stopRecording() }
        function toggle(): void { Capture.toggleRecording() }
        function cancel(): void { Capture.cancel() }
        function status(): string { return JSON.stringify({ canRecord: Capture.canRecord, canPick: Capture.canPick, recording: Capture.recording, elapsed: Capture.elapsed, file: Capture.lastFile, delay: Prefs.captureDelay }) }
    }

    // qs ipc call switcher <next | prev | toggle>   Alt+Tab: bind next / prev; the modifier coming up picks the window
    IpcHandler {
        target: "switcher"
        function next(): void { Switcher.press(1) }
        function prev(): void { Switcher.press(-1) }
        function toggle(): void { Switcher.toggle() }
    }

    // qs ipc call power <status | profile saver|balanced|performance | cycle>
    IpcHandler {
        target: "power"
        function status(): string {
            return JSON.stringify({ battery: Power.hasBattery, percent: Power.level, charging: Power.charging, full: Power.full, time: Power.timeText, health: Power.health,
                                    profileAvailable: Power.profileAvailable, profile: Power.current.name, profiles: Power.offered.map(p => p.name), warnAt: Prefs.batteryWarnPct })
        }
        function profile(name: string): void { Power.setProfileByName(name) }
        function cycle(): void { Power.cycle() }
    }

    // qs ipc call lock lock     (bind to a key, or call from `loginctl lock-session` handlers)
    // qs ipc call idle <toggle | keepAwake true|false>   hold back idle lock / screen-off
    IpcHandler {
        target: "lock"
        function lock(): void { Lock.lock() }
        function locked(): bool { return Lock.locked }
    }
    IpcHandler {
        target: "idle"
        function toggle(): void { Idle.toggle() }
        function keepAwake(on: bool): void { Idle.keepAwake = on }
        function status(): string { return JSON.stringify({ keepAwake: Idle.keepAwake, lockMin: Prefs.idleLockMin, offMin: Prefs.idleOffMin }) }
    }

    // qs ipc call settings <save [PATH] | restore [PATH] | status>   save / restore Settings and config.json as one file (default ~/ushell-settings.json)
    IpcHandler {
        target: "settings"
        function save(path: string): void { Backup.exportTo(path) }
        function restore(path: string): void { Backup.importFrom(path) }
        function status(): string { return JSON.stringify({ busy: Backup.busy, failed: Backup.failed, message: Backup.status }) }
    }

    // qs ipc call auth status   (the polkit password prompt: is ushell the session's agent, and is a request waiting)
    IpcHandler {
        target: "auth"
        function status(): string {
            return JSON.stringify({ enabled: Auth.enabled, registered: Auth.registered, active: Auth.active,
                                    message: Auth.flow ? Auth.flow.message : "", action: Auth.flow ? Auth.flow.actionId : "" })
        }
        function cancel(): void { Auth.cancel() }
    }

    // qs ipc call osd test   (show the volume pill)
    IpcHandler {
        target: "osd"
        function test(): void { Osd.show("volume", Audio.volume, Audio.muted) }
    }

    // qs ipc call shell toggle <launcher|sound|media|clipboard|settings|power|widgets|wallpapers|appearance|notifications|network|bluetooth|capture|calendar|switcher|minimap>   (settings is a window)
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name) }
        function open(name: string): void   { Shell.open(name) }
        // qs ipc call shell settings <general|appearance|notifications|power|weather|about>   open the settings window on a section
        function settings(page: string): void { Shell.openSettings(page) }
        function close(): void              { Shell.close() }
        // qs ipc call shell tab <0..3>   show the control centre (widgets panel) on a tab for a few seconds: 0 control, 1 system, 2 weather, 3 focus
        // qs ipc call shell brightness <+N|-N>   change brightness of all monitors by N percent
        function brightness(delta: int): void { Brightness.step(delta) }
        function tab(index: int): void      { Shell.peekWidgets(index) }
        // qs ipc call shell wallpaper <next|prev|random|off|/path/to/picture>
        function wallpaper(arg: string): void { Wallpapers.command(arg) }
        // qs ipc call shell colors <true|false>   the theme's colours follow the wallpaper (or stay on the chosen accent)
        function colors(on: bool): void { Prefs.set("wallpaperColors", on) }
        // qs ipc call shell theme <dark|light|toggle>   (e.g. from a day/night timer)
        function theme(mode: string): void {
            if (mode === "toggle") Prefs.set("themeMode", Prefs.themeMode === "dark" ? "light" : "dark")
            else if (mode === "dark" || mode === "light") Prefs.set("themeMode", mode)
        }
    }
}
