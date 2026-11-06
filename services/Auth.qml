pragma Singleton
import Quickshell
import Quickshell.Services.Polkit
import QtQuick

// The login prompt for privileged actions (pkexec, NetworkManager, the VPN kill switch ...): ushell registers
// itself as the session's polkit authentication agent and modules/polkit/AuthPrompt.qml asks for the password.
// Only one agent can be registered per session: stop polkit-gnome / polkit-kde-authentication-agent-1 (and their
// autostart) or whichever registers second does not get the requests.
//
//   qs ipc call auth status
Singleton {
    id: root

    readonly property bool enabled: Prefs.polkitAgent
    readonly property bool registered: loader.item ? loader.item.isRegistered : false
    readonly property var flow: loader.item ? loader.item.flow : null
    readonly property bool active: flow !== null

    function submit(text) { if (flow) flow.submit(text) }
    function cancel() { if (flow) flow.cancelAuthenticationRequest() }

    Loader {
        id: loader
        active: root.enabled
        sourceComponent: PolkitAgent {}
    }
}
