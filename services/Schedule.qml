pragma Singleton
import Quickshell
import QtQuick
import "dnd.js" as Dnd

// Day / night schedule: from Prefs.themeLightFrom the theme is light, from Prefs.themeDarkFrom it is dark, and
// (if asked) the night light is on for the dark part. It acts when the time crosses one of the two moments and
// when it is switched on, so a manual change in between stands until the next one.
Singleton {
    id: root

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool day: Dnd.inWindow(Prefs.themeLightFrom, Prefs.themeDarkFrom, clock.date)
    property int last: -1                      // the part of the day that was applied last: 1 day, 0 night

    function apply() {
        if (!Prefs.themeSchedule || !Prefs.loaded) { last = -1; return }
        const now = day ? 1 : 0
        if (now === last) return
        last = now
        Prefs.set("themeMode", day ? "light" : "dark")
        if (Prefs.scheduleNightLight && !Prefs.nightSchedule) Prefs.set("nightLight", !day)   // an own night schedule takes over
    }
    onDayChanged: apply()

    // Night light on its own clock (Prefs.nightFrom to Prefs.nightTo, may cross midnight), independent of the theme.
    // Like the theme schedule it acts when the time crosses one of the two moments and when it is switched on.
    readonly property bool night: Dnd.inWindow(Prefs.nightFrom, Prefs.nightTo, clock.date)
    property int lastNight: -1                 // the part of the day applied last: 1 night, 0 day
    function applyNight() {
        if (!Prefs.nightSchedule || !Prefs.loaded) { lastNight = -1; return }
        const now = night ? 1 : 0
        if (now === lastNight) return
        lastNight = now
        Prefs.set("nightLight", night)
    }
    onNightChanged: applyNight()

    Connections {
        target: Prefs
        function onThemeScheduleChanged() { root.last = -1; root.apply() }
        function onThemeLightFromChanged() { root.apply() }
        function onThemeDarkFromChanged() { root.apply() }
        function onNightScheduleChanged() { root.lastNight = -1; root.applyNight() }
        function onNightFromChanged() { root.applyNight() }
        function onNightToChanged() { root.applyNight() }
        function onLoadedChanged() { root.apply(); root.applyNight() }
    }
    Component.onCompleted: { apply(); applyNight() }
}
