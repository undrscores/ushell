pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// First playing MPRIS player, else the first available one.
Singleton {
    id: root
    readonly property var player: {
        const ps = Mpris.players.values
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null
    }
    readonly property bool available: player !== null
    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title:  player ? (player.trackTitle  || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string art:    player ? (player.trackArtUrl || "") : ""

    readonly property real length:   player && player.lengthSupported ? player.length : 0
    property real position: 0
    readonly property string identity: player ? (player.identity || "") : ""
    function seek(frac) { if (player && player.canSeek && length > 0) player.position = frac * length }

    // MPRIS positions don't push updates; poll while something plays.
    Timer {
        interval: 500
        repeat: true
        running: root.playing
        triggeredOnStart: true
        onTriggered: if (root.player) { root.player.positionChanged(); root.position = root.player.position }
    }
    onPlayerChanged: position = player ? player.position : 0

    function toggle() { if (player) player.togglePlaying() }
    function next()   { if (player) player.next() }
    function prev()   { if (player) player.previous() }
}
