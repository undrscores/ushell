//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "modules/leftbar"
import "modules/widgets"
import "modules/launcher"
import "modules/quicksettings"
import "modules/calendar"
import "modules/clipboard"
import "modules/settings"
import "modules/media"
import "modules/power"
import "modules/wallpaper"
import "modules/appearance"
import "modules/notifications"
import "modules/osd"
import "modules/network"
import "modules/lock"
import "modules/idle"
import "services"
import "config"

ShellRoot {
    // singletons are created lazily; touch the clipboard and the notification daemon so they start with the shell
    readonly property var warm: [Clipboard.items.length, Notifications.count, LockKeys.seen]

    // the saved theme choice drives the Theme singleton
    Binding { target: Theme; property: "mode"; value: Prefs.themeMode }
    Binding { target: Theme; property: "accentName"; value: Prefs.accent }
    Binding { target: Theme; property: "wallHue"; value: Wallpapers.useColors ? Wallpapers.hue : -1 }
    Binding { target: Theme; property: "wallSat"; value: Wallpapers.sat }

    ThemeExport {}
    Wallpaper {}
    LockScreen {}
    IdleHandler {}

    Bar {}
    LeftBar {}
    Widgets {}
    Launcher { id: launcher }
    QuickSettings {}
    CalendarMenu {}
    MediaMenu {}
    ClipboardMenu {}
    SettingsMenu {}
    PowerMenu {}
    WallpaperPicker {}
    AppearanceMenu {}
    NetworkMenu {}
    NotificationPopups {}
    NotificationsMenu {}
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

    // qs ipc call network <status | scan | wifi true|false>
    IpcHandler {
        target: "network"
        function status(): string {
            return JSON.stringify({ available: Network.available, kind: Network.kind, name: Network.name, online: Network.online,
                                    connectivity: Network.connectivity, wifiPresent: Network.wifiPresent, wifiOn: Network.wifiOn,
                                    networks: Network.networks.map(n => n.ssid + " " + n.signal + (n.active ? " *" : "")) })
        }
        function scan(): void { Network.scan() }
        function wifi(on: bool): void { Network.setWifi(on) }
    }

    // qs ipc call keys status     (Caps / Num Lock, keyboard layout, apps recording from a microphone)
    IpcHandler {
        target: "keys"
        function status(): string {
            return JSON.stringify({ caps: LockKeys.caps, num: LockKeys.num, seen: LockKeys.seen, layouts: Niri.layouts, layout: Niri.layoutShort,
                                    micInUse: Audio.micInUse, recorders: Audio.recorderNames })
        }
        function layoutOsd(): void { Osd.showText("layout", Niri.layoutName || "English (US)", true) }
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

    // qs ipc call osd test   (show the volume pill)
    IpcHandler {
        target: "osd"
        function test(): void { Osd.show("volume", Audio.volume, Audio.muted) }
    }

    // qs ipc call shell toggle <launcher|quicksettings|calendar|media|clipboard|settings|power|widgets|wallpapers|appearance|notifications|network>
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name) }
        function open(name: string): void   { Shell.open(name) }
        function close(): void              { Shell.close() }
        // qs ipc call shell tab <0|1|2>   open the widgets panel on a tab
        // qs ipc call shell brightness <+N|-N>   change brightness of all monitors by N percent
        function brightness(delta: int): void { Brightness.step(delta) }
        function tab(index: int): void      { Shell.widgetsTab = index; Shell.widgetsPinned = true }
        // qs ipc call shell wallpaper <next|prev|random|off|/path/to/picture>
        function wallpaper(arg: string): void { Wallpapers.command(arg) }
        // qs ipc call shell theme <dark|light|toggle>   (e.g. from a day/night timer)
        function theme(mode: string): void {
            if (mode === "toggle") Prefs.set("themeMode", Prefs.themeMode === "dark" ? "light" : "dark")
            else if (mode === "dark" || mode === "light") Prefs.set("themeMode", mode)
        }
    }
}
