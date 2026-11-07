pragma Singleton
import Quickshell
import QtQuick
import "../config"

// On-screen display: a small pill near the bottom of the focused screen when the volume, the microphone
// mute or the brightness changes, whoever changed it (a keybind, wpctl, the bar's scroll wheel, a slider).
// It watches the values rather than the keys, so it needs no keybind of its own.
//
// Nothing is shown for: the first 2 s after login (PipeWire and the monitors are still reporting in),
// a different default device appearing (switching headphones is not a volume change), or while Quick
// Settings is open (its sliders are the display).
Singleton {
    id: root

    property string kind: "volume"       // volume | mic | brightness | caps | num | layout | timer | note   (all but the first three show `text`)
    property string text: ""             // for the text pills
    property string customGlyph: ""      // icon for a text pill that brings its own (capture, battery ...)
    readonly property bool isText: kind === "caps" || kind === "num" || kind === "layout" || kind === "timer" || kind === "note"
    property real value: 0               // 1 = 100 %; volume can go above 1 up to Config.maxVolume
    property bool muted: false
    property bool shown: false

    readonly property real limit: kind === "volume" ? Math.max(1, Config.maxVolume) : 1   // value at which the bar is full
    readonly property string glyph: {
        if (isText && customGlyph !== "") return customGlyph
        if (kind === "timer") return "\uf017"
        if (kind === "brightness") return ""
        if (kind === "mic") return muted ? "" : ""
        if (muted || value <= 0) return ""
        return value < 0.5 ? "" : ""
    }

    property bool armed: false
    Timer { interval: 2000; running: true; onTriggered: { root.armed = true; root.sync() } }
    Timer { id: hideTimer; interval: 1600; onTriggered: root.shown = false }

    // a pill with words instead of a bar: Caps Lock on, the keyboard layout that was switched to
    function showText(k, t, on, g) {
        kind = k
        text = t
        customGlyph = g || ""
        muted = false
        value = on ? 1 : 0
        shown = true
        hideTimer.restart()
    }

    function show(k, v, m) {
        kind = k
        customGlyph = ""
        value = v
        muted = m
        shown = true
        hideTimer.restart()
    }

    // ---- change detection -----------------------------------------------------------------------------
    property var last: ({})              // kind -> { node, value, muted }: what was on screen / last seen
    function rebase(k) { delete last[k] }

    // `node` identifies the device the value belongs to; a new device only re-bases. trackValue = false
    // reacts to the mute state alone (the microphone: apps adjust its level themselves).
    function observe(k, node, v, m, quiet, trackValue) {
        if (!node) { rebase(k); return }
        const prev = last[k]
        last[k] = { node: node, value: v, muted: m }
        if (quiet || !prev || prev.node !== node) return
        const same = (!trackValue || Math.abs(prev.value - v) < 0.0005) && prev.muted === m
        if (!same) show(k, v, m)
    }

    function sync() {
        const quiet = !armed
        observe("volume", Audio.sink ? Audio.sink.name : "", Audio.volume, Audio.muted, quiet, true)
        observe("mic", Audio.source ? Audio.source.name : "", Audio.micVolume, Audio.micMuted, quiet, false)
        if (Brightness.ready) observe("brightness", "monitors", Brightness.average / 100, false, quiet, true)
        else rebase("brightness")
    }

    Connections {
        target: Audio
        function onSinkChanged() { root.sync() }
        function onSourceChanged() { root.sync() }
        function onVolumeChanged() { root.sync() }
        function onMutedChanged() { root.sync() }
        function onMicVolumeChanged() { root.sync() }
        function onMicMutedChanged() { root.sync() }
    }
    Connections {
        target: Brightness
        function onReadyChanged() { root.sync() }
        function onAverageChanged() { root.sync() }
    }
}
