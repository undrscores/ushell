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

    function toggle() { if (player) player.togglePlaying() }
    function next()   { if (player) player.next() }
    function prev()   { if (player) player.previous() }
}
