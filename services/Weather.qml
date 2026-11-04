pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

// Open-Meteo forecast. Location: Prefs.weatherCity (geocoded) or the IP address.
// Fetches lazily (first time the Weather tab is seen, then at most every 20 min).
Singleton {
    id: root
    property bool loading: false
    property bool ok: false
    property string error: ""
    property string place: ""
    property double updated: 0

    property real temp: 0
    property real feels: 0
    property int humidity: 0
    property real wind: 0
    property int code: 0
    property bool isDay: true
    property var daily: []          // [{ date, code, max, min }]

    readonly property string tempUnit: Prefs.weatherMetric ? "°C" : "°F"
    readonly property string windUnit: Prefs.weatherMetric ? "km/h" : "mph"

    property real lat: 0
    property real lon: 0
    property bool located: false
    property int attempt: 0
    // IP geolocation providers, tried in order (unused when Prefs.weatherCity is set)
    readonly property var ipProviders: ["https://ipwho.is/", "https://ipapi.co/json/"]

    Connections {
        target: Prefs
        function onWeatherCityChanged() { root.restart(true) }
        function onWeatherMetricChanged() { root.restart(false) }
    }
    function ensure() { if (!loading && Date.now() - updated > 20 * 60 * 1000) refresh() }
    function refresh() {
        if (loading) return
        loading = true
        error = ""
        attempt = 0
        if (located) forecast.running = true
        else locate.running = true
    }
    function fail(msg) { error = msg; if (!ok) place = ""; finish() }

    // A setting changed. A new city must be geocoded again (`located` would otherwise pin the old
    // coordinates); if a fetch is already running, go again when it ends instead of being ignored.
    property bool rerun: false
    property bool relocate: false
    function restart(newPlace) {
        if (loading) { rerun = true; relocate = relocate || newPlace; return }
        if (newPlace) located = false
        refresh()
    }
    function finish() {
        loading = false
        if (!rerun) return
        rerun = false
        if (relocate) { located = false; relocate = false }
        refresh()
    }

    // WMO weather code -> label + Nerd Font glyph
    function describe(code, day) {
        if (code === 0)  return { text: day ? "Clear" : "Clear night",  icon: day ? "" : "" }
        if (code === 1)  return { text: "Mostly clear",  icon: day ? "" : "" }
        if (code === 2)  return { text: "Partly cloudy", icon: day ? "" : "" }
        if (code === 3)  return { text: "Overcast",      icon: "" }
        if (code === 45 || code === 48) return { text: "Fog", icon: "" }
        if (code >= 51 && code <= 57) return { text: "Drizzle", icon: "" }
        if (code >= 61 && code <= 67) return { text: "Rain",    icon: "" }
        if (code >= 71 && code <= 77) return { text: "Snow",    icon: "" }
        if (code >= 80 && code <= 82) return { text: "Showers", icon: "" }
        if (code === 85 || code === 86) return { text: "Snow showers", icon: "" }
        if (code >= 95) return { text: "Thunderstorm", icon: "" }
        return { text: "Unknown", icon: "" }
    }

    Process {
        id: locate
        command: Prefs.weatherCity !== ""
            ? ["curl", "-sf", "-m", "10", "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(Prefs.weatherCity)]
            : ["curl", "-sf", "-m", "10", root.ipProviders[Math.min(root.attempt, root.ipProviders.length - 1)]]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const r = Prefs.weatherCity !== "" ? j.results[0] : j
                    if (!r || r.latitude === undefined || r.success === false) throw new Error("no location")
                    root.lat = r.latitude
                    root.lon = r.longitude
                    root.place = r.city || r.name || Prefs.weatherCity
                    root.located = true
                    forecast.running = true
                } catch (e) {
                    // try the next IP provider before giving up
                    if (Prefs.weatherCity === "" && root.attempt + 1 < root.ipProviders.length) {
                        root.attempt++
                        locate.running = true
                    } else root.fail("Couldn't find your location")
                }
            }
        }
    }
    Process {
        id: forecast
        command: ["curl", "-sf", "-m", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5&timezone=auto"
            + (Prefs.weatherMetric ? "" : "&temperature_unit=fahrenheit&wind_speed_unit=mph")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const c = j.current
                    root.temp = c.temperature_2m
                    root.feels = c.apparent_temperature
                    root.humidity = c.relative_humidity_2m
                    root.wind = c.wind_speed_10m
                    root.code = c.weather_code
                    root.isDay = c.is_day === 1
                    const d = j.daily
                    root.daily = d.time.map((t, i) => ({ date: t, code: d.weather_code[i], max: d.temperature_2m_max[i], min: d.temperature_2m_min[i] }))
                    root.ok = true
                    root.updated = Date.now()
                    root.finish()
                } catch (e) { root.fail("Couldn't reach the weather service") }
            }
        }
    }
    Timer { interval: 30 * 60 * 1000; repeat: true; running: root.ok; onTriggered: root.refresh() }
}
