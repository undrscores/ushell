pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default sink/source state + control. UI never touches PipeWire directly.
Singleton {
    id: root
    readonly property PwNode sink:   Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume:  sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted:   sink && sink.audio ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted:  source && source.audio ? source.audio.muted : false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    function setVolume(v)    { if (sink && sink.audio)   { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)) } }
    function setMicVolume(v) { if (source && source.audio) { source.audio.muted = false; source.audio.volume = Math.max(0, Math.min(1, v)) } }
    function toggleMute()    { if (sink && sink.audio)   sink.audio.muted = !sink.audio.muted }
    function toggleMic()     { if (source && source.audio) source.audio.muted = !source.audio.muted }
    function setSink(node)   { Pipewire.preferredDefaultAudioSink = node }
    function nodeName(n)     { return n ? (n.description || n.nickname || n.name) : "" }

    function icon() {
        if (muted || volume <= 0) return ""
        return volume < 0.5 ? "" : ""
    }

    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks) }
}
