pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "nm.js" as NM

// Network state and Wi-Fi control through NetworkManager's `nmcli` (nothing is done if it is not installed:
// `available` stays false and the bar hides the icon). Event-driven: `nmcli monitor` reports changes and
// the state is re-read then. Wi-Fi networks are only listed (and rescanned) while the panel is open.
//
// Passwords are handed to nmcli on its stdin (`--ask`), never on the command line.
Singleton {
    id: root

    property bool available: false           // nmcli ran at all
    property string kind: "none"             // ethernet | wifi | none
    property string name: ""                 // the active connection
    property string device: ""
    property bool wifiPresent: false         // there is a Wi-Fi adapter
    property bool wifiOn: false
    property string connectivity: "unknown"  // full | limited | portal | none | unknown
    property var networks: []                // [{ ssid, signal, secured, active, saved }]
    property var saved: []
    property bool scanning: false
    property string busySsid: ""             // network being connected to
    property var vpns: []                    // [{ name, type: "vpn" | "wireguard", active }]
    property string busyVpn: ""              // VPN being switched
    readonly property bool vpnOn: vpns.some(v => v.active)
    readonly property string vpnName: (vpns.find(v => v.active) ?? { name: "" }).name
    property string error: ""

    readonly property bool online: kind !== "none" && connectivity !== "none"
    readonly property bool wanted: Shell.overlay === "network"      // panel open: list and rescan networks

    // glyph for the bar: wired, Wi-Fi, or a warning triangle for "no network"
    readonly property string glyph: {
        if (kind === "ethernet") return "󰈀"
        if (kind === "wifi") return ""
        return wifiOn || !wifiPresent ? "" : ""
    }
    readonly property bool dim: kind === "none" || connectivity === "limited" || connectivity === "portal"

    function setVpn(name, on) {
        if (act.running) return                 // another change is still in progress: the switch snaps back on the next refresh
        busyVpn = name
        error = ""
        run(["nmcli", "connection", on ? "up" : "down", "id", name])
    }
    function refresh() {
        vpnProc.running = true
        statusProc.running = true
        radioProc.running = true
        connProc.running = true
        if (wanted) { savedProc.running = true }
    }
    function scan() {
        if (!wifiPresent || !wifiOn) return
        scanning = true
        wifiProc.command = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
        wifiProc.running = true
    }
    function setWifi(on) { run(["nmcli", "radio", "wifi", on ? "on" : "off"]) }
    function disconnect() { if (device !== "") run(["nmcli", "device", "disconnect", device]) }
    function forget(ssid) { run(["nmcli", "connection", "delete", "id", ssid]) }

    // Connect to a network: a saved one just comes up, a new secured one needs `password`.
    function connect(net, password) {
        busySsid = net.ssid
        error = ""
        if (net.saved) run(["nmcli", "connection", "up", "id", net.ssid])
        else if (net.secured) run(["nmcli", "--ask", "device", "wifi", "connect", net.ssid], (password || "") + "\n")
        else run(["nmcli", "device", "wifi", "connect", net.ssid])
    }

    onWantedChanged: if (wanted) { error = ""; savedProc.running = true; scan() }

    // ---- reading state --------------------------------------------------------------------------------------
    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = NM.parseStatus(text)
                root.available = true
                root.kind = s.kind; root.name = s.name; root.device = s.device; root.wifiPresent = s.wifiPresent
            }
        }
        onExited: code => { if (code !== 0) root.available = false }
    }
    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector { onStreamFinished: root.vpns = NM.parseVpn(text) }
    }
    Process {
        id: radioProc
        command: ["nmcli", "-t", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiOn = text.trim() === "enabled" }
    }
    Process {
        id: connProc
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general"]
        stdout: StdioCollector { onStreamFinished: root.connectivity = text.trim() || "unknown" }
    }
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: { root.saved = NM.parseSavedWifi(text); if (root.wanted) wifiListProc.running = true }
        }
    }
    // the list without a rescan: cheap, used whenever something changed
    Process {
        id: wifiListProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector { onStreamFinished: root.networks = NM.parseWifi(text, root.saved) }
    }
    // the list after a rescan (explicit, when the panel opens or the user asks)
    Process {
        id: wifiProc
        stdout: StdioCollector {
            onStreamFinished: { root.networks = NM.parseWifi(text, root.saved); root.scanning = false }
        }
        onExited: root.scanning = false
    }

    // ---- doing things ---------------------------------------------------------------------------------------
    property string pendingInput: ""
    function run(cmd, input) {
        if (act.running) return
        pendingInput = input || ""
        act.command = cmd
        act.running = true
    }
    Process {
        id: act
        stdinEnabled: true
        stderr: StdioCollector { id: actErr }
        stdout: StdioCollector { id: actOut }
        onStarted: if (root.pendingInput !== "") { write(root.pendingInput); root.pendingInput = "" }
        onExited: code => {
            root.error = code === 0 ? "" : (actErr.text.trim() || actOut.text.trim() || "Could not connect").split("\n").pop()
            root.busySsid = ""
            root.busyVpn = ""
            root.refresh()
        }
    }

    // ---- staying current ------------------------------------------------------------------------------------
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: line => debounce.restart() }
        onExited: monitorRestart.start()
    }
    Timer { id: monitorRestart; interval: 5000; onTriggered: monitor.running = true }
    Timer { id: debounce; interval: 400; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
