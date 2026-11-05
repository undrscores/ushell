pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../config"

// Default sink/source state + control. UI never touches PipeWire directly.
Singleton {
    id: root
    readonly property PwNode sink:   Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume:  sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted:   sink && sink.audio ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted:  source && source.audio ? source.audio.muted : false

    readonly property var sinks:   Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    // Applications: every audio stream, then only the playing ones (output streams) via isPlayback().
    readonly property var streamNodes: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
    readonly property var streams: streamNodes.filter(n => root.isPlayback(n))

    // Output stream (an app playing sound) as opposed to a recording one. PipeWire says so in the node's
    // media.class; that is only readable once the node is tracked (see the tracker below), until then the
    // sink flag decides.
    function isPlayback(n) {
        const p = n.properties
        const cls = p ? p["media.class"] : undefined
        return cls ? cls === "Stream/Output/Audio" : n.isSink
    }
    function appName(n) {
        if (!n) return ""
        const p = n.properties || {}
        return p["application.name"] || p["application.process.binary"] || n.description || n.nickname || n.name
    }

    function clampVolume(v) { return Math.max(0, Math.min(Config.maxVolume, v)) }
    function setNodeVolume(n, v) { if (n && n.audio) { n.audio.muted = false; n.audio.volume = clampVolume(v) } }
    function toggleNodeMute(n)   { if (n && n.audio) n.audio.muted = !n.audio.muted }

    function setVolume(v)    { setNodeVolume(sink, v) }
    function setMicVolume(v) { if (source && source.audio) { source.audio.muted = false; source.audio.volume = Math.max(0, Math.min(1, v)) } }
    function toggleMute()    { if (sink && sink.audio)   sink.audio.muted = !sink.audio.muted }
    function toggleMic()     { if (source && source.audio) source.audio.muted = !source.audio.muted }
    function setSink(node)   { Pipewire.preferredDefaultAudioSink = node }
    function setSource(node) { Pipewire.preferredDefaultAudioSource = node }
    function nodeName(n)     { return n ? (n.description || n.nickname || n.name) : "" }

    function icon() {
        if (muted || volume <= 0) return ""
        return volume < 0.5 ? "" : ""
    }

    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks, root.sources, root.streamNodes) }
}
