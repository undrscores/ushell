pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Bluetooth state for the bar and the Bluetooth menu, from BlueZ through Quickshell.Bluetooth.
// `available` is false when there is no adapter or the bluetooth service is not running.
Singleton {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool on: available && adapter.enabled
    readonly property bool scanning: on && adapter.discovering

    // connected first, then paired, then the rest; unnamed ones left out
    readonly property var devices: {
        if (!adapter) return []
        const list = adapter.devices.values.filter(d => (d.name || d.deviceName) !== "")
        const rank = d => d.connected ? 0 : (d.paired ? 1 : 2)
        return list.sort((a, b) => rank(a) - rank(b) || (a.name || a.deviceName).localeCompare(b.name || b.deviceName))
    }
    readonly property int connectedCount: devices.filter(d => d.connected).length

    readonly property string glyph: !on ? "" : (connectedCount > 0 ? "" : "")

    function label(d) { return d.name || d.deviceName || d.address }
    function setOn(v) { if (adapter) adapter.enabled = v }
    function scan(v) { if (on) adapter.discovering = v }

    // tap a device: connect it (pairing first when it is new), or disconnect it when it is connected
    function toggle(d) {
        if (d.connected) d.disconnect()
        else if (d.paired) d.connect()
        else { pending = d.address; d.pair() }   // new device: pair, then the menu trusts and connects it
    }
    property string pending: ""            // address of the device being paired by a click
}
