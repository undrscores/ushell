pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// One "now playing" view over two backends: MPRIS players (browsers, mpv, ...) and MPD.
// A playing source wins; otherwise a paused MPRIS player, then a paused MPD.
Singleton {
    id: root

    readonly property var player: {
        const ps = Mpris.players.values
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null
    }
    readonly property bool mprisPlaying: player ? player.isPlaying : false
    readonly property bool useMpd: !mprisPlaying && (Mpd.playing || (player === null && Mpd.active))

    readonly property bool available: useMpd || player !== null
    readonly property bool playing: useMpd ? Mpd.playing : mprisPlaying
    readonly property string title:  useMpd ? Mpd.title  : (player ? (player.trackTitle  || "") : "")
    readonly property string artist: useMpd ? Mpd.artist : (player ? (player.trackArtist || "") : "")
    readonly property string art:    useMpd ? Mpd.art    : (player ? (player.trackArtUrl || "") : "")
    readonly property string identity: useMpd ? "MPD" : (player ? (player.identity || "") : "")
    readonly property real length: useMpd ? Mpd.duration : (player && player.lengthSupported ? player.length : 0)
    property real position: 0

    function seek(frac) {
        if (length <= 0) return
        if (useMpd) Mpd.seek(frac * length)
        else if (player && player.canSeek) player.position = frac * length
    }
    function toggle() { if (useMpd) Mpd.toggle(); else if (player) player.togglePlaying() }
    function next()   { if (useMpd) Mpd.next();   else if (player) player.next() }
    function prev()   { if (useMpd) Mpd.prev();   else if (player) player.previous() }

    // Positions don't push updates: poll (MPD is interpolated between its ticks). Only the full player shows the
    // position, so nothing polls while it is closed.
    Timer {
        interval: 400
        repeat: true
        running: root.playing && Shell.mediaFull
        triggeredOnStart: true
        onTriggered: root.syncPosition()
    }
    function syncPosition() {
        if (useMpd) position = Math.min(Mpd.duration, Mpd.elapsed + (Mpd.playing ? (Date.now() - Mpd.stamp) / 1000 : 0))
        else if (player) { player.positionChanged(); position = player.position }
    }
    Connections { target: Shell; function onMediaFullChanged() { if (Shell.mediaFull) root.syncPosition() } }   // a paused player still needs its position when the full player opens
    onUseMpdChanged: syncPosition()
    onPlayerChanged: syncPosition()
    Connections { target: Mpd; function onElapsedChanged() { if (root.useMpd && !root.playing) root.syncPosition() } }
}
