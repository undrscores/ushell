pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../config"

// Battery (through UPower) and the power profile (power-profiles-daemon, or anything else that offers
// org.freedesktop.UPower.PowerProfiles). Both are optional: a desktop has no battery, and without the daemon
// `profileAvailable` stays false, and the panels simply leave their rows out.
//
//   qs ipc call power <status | profile saver|balanced|performance | cycle>
Singleton {
    id: root

    // ---- battery ---------------------------------------------------------------------------------------
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: !!dev && dev.ready && dev.isPresent
    readonly property real pct: {
        if (!hasBattery) return 0
        const p = dev.percentage
        return Math.max(0, Math.min(100, p <= 1 ? p * 100 : p))     // 0..1 (Quickshell) or already 0..100
    }
    readonly property int level: Math.round(pct)
    readonly property bool charging: hasBattery && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: hasBattery && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: hasBattery && (dev.state === UPowerDeviceState.Discharging || dev.state === UPowerDeviceState.PendingDischarge)
    readonly property bool low: discharging && Prefs.batteryWarnPct > 0 && level <= Prefs.batteryWarnPct

    function duration(secs) {
        if (!(secs > 0)) return ""
        const m = Math.round(secs / 60)
        return m < 60 ? m + " min" : Math.floor(m / 60) + " h " + (m % 60 < 10 ? "0" : "") + (m % 60) + " min"
    }
    readonly property string timeText: {
        if (!hasBattery) return ""
        if (charging) { const t = duration(dev.timeToFull); return t !== "" ? t + " until full" : "Charging" }
        if (full) return "Fully charged"
        if (discharging) { const t = duration(dev.timeToEmpty); return t !== "" ? t + " left" : "On battery" }
        return ""
    }
    readonly property string glyph: {
        if (charging) return ""
        if (level >= 88) return ""
        if (level >= 63) return ""
        if (level >= 38) return ""
        if (level >= 13) return ""
        return ""
    }
    readonly property int health: hasBattery && dev.healthSupported ? Math.round(dev.healthPercentage) : -1

    // ---- warning and automatic power saver ---------------------------------------------------------------
    property bool warned: false
    property bool warnedCritical: false
    property int savedProfile: -1                // profile to go back to after the automatic power saver

    function check() {
        if (!discharging) {
            if (warned || warnedCritical) { warned = false; warnedCritical = false }
            if (savedProfile >= 0 && profileAvailable) { PowerProfiles.profile = savedProfile; savedProfile = -1 }
            return
        }
        if (low && !warned) {
            warned = true
            Osd.showText("note", "Battery low · " + level + "%", true, glyph)
            if (Prefs.autoPowerSaver && profileAvailable && PowerProfiles.profile !== PowerProfile.PowerSaver) {
                savedProfile = PowerProfiles.profile
                PowerProfiles.profile = PowerProfile.PowerSaver
            }
        }
        if (level <= 5 && !warnedCritical) {
            warnedCritical = true
            Osd.showText("note", "Battery almost empty · " + level + "%", true, glyph)
        }
        if (!low && level > Prefs.batteryWarnPct + 3) warned = false
    }
    onLevelChanged: check()
    onDischargingChanged: check()
    onLowChanged: check()

    // ---- power profile -----------------------------------------------------------------------------------
    property bool profileAvailable: false
    readonly property var profiles: [
        { id: PowerProfile.PowerSaver,  name: "saver",       title: "Saver",       glyph: "" },
        { id: PowerProfile.Balanced,    name: "balanced",    title: "Balanced",    glyph: "" },
        { id: PowerProfile.Performance, name: "performance", title: "Performance", glyph: "" }
    ]
    readonly property var offered: profiles.filter(p => p.id !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
    readonly property var current: profiles.find(p => p.id === PowerProfiles.profile) ?? profiles[1]

    function setProfile(id) {
        if (!profileAvailable) return
        savedProfile = -1                        // a choice made by hand stands
        PowerProfiles.profile = id
    }
    function setProfileByName(name) {
        const p = offered.find(x => x.name === name)
        if (p) setProfile(p.id)
    }
    function cycle() {
        const o = offered
        const i = o.findIndex(p => p.id === PowerProfiles.profile)
        setProfile(o[(i + 1) % o.length].id)
    }

    // reading a property activates the daemon through D-Bus; if that works, the profile switch will too
    Process {
        command: ["busctl", "--system", "--no-pager", "get-property", "org.freedesktop.UPower.PowerProfiles",
                  "/org/freedesktop/UPower/PowerProfiles", "org.freedesktop.UPower.PowerProfiles", "ActiveProfile"]
        running: true
        onExited: code => root.profileAvailable = code === 0
    }
}
