import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Network dropdown (the network icon in the top pill, or `qs ipc call shell toggle network`): the current
// connection, the Wi-Fi switch and the networks in range. Click a network to join it; a new secured one
// asks for its password first. Right-click a saved one to forget it.
Overlay {
    id: root
    name: "network"

    property string asking: ""           // SSID whose password is being typed
    onOpenChanged: if (!open) asking = ""

    DropCard {
        id: card
        open: root.open
        contentWidth: 320
        contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 12

            // current connection
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Icon { text: Network.glyph; size: 20; color: Network.dim ? Theme.danger : Theme.accent; Layout.preferredWidth: 28 }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: Network.kind === "none" ? "Not connected" : Network.name
                        color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: {
                            if (!Network.available) return "NetworkManager is not running"
                            const k = Network.kind === "ethernet" ? "Wired" : Network.kind === "wifi" ? "Wi-Fi" : ""
                            const c = Network.connectivity === "full" ? "online" : Network.connectivity === "limited" ? "no internet"
                                    : Network.connectivity === "portal" ? "sign-in needed" : Network.connectivity === "none" ? "offline" : ""
                            return [k, c].filter(x => x).join(" · ")
                        }
                        color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                    }
                }
                Pill { visible: Network.kind !== "none"; label: "Disconnect"; onClicked: Network.disconnect() }
            }

            Text {
                Layout.fillWidth: true
                visible: Network.error !== ""
                text: Network.error
                wrapMode: Text.Wrap
                color: Theme.danger; font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            }

            // VPN and WireGuard profiles saved in NetworkManager
            ColumnLayout {
                Layout.fillWidth: true
                visible: Network.vpns.length > 0
                spacing: 8
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
                SectionLabel { text: "VPN" }
                Repeater {
                    model: Network.vpns.slice(0, 8)
                    delegate: RowLayout {
                        id: vpn
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12
                        Icon { text: "\uf132"; size: 15; color: vpn.modelData.active ? Theme.accent : Theme.fgDim; Layout.preferredWidth: 28 }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: vpn.modelData.name + (Network.busyVpn === vpn.modelData.name ? "  …" : "")
                            color: vpn.modelData.active ? Theme.fg : Theme.fgDim
                            font { family: Theme.font; pixelSize: Theme.fontSize }
                        }
                        Text { text: vpn.modelData.type === "wireguard" ? "WireGuard" : "VPN"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 3 } }
                        Switch { checked: vpn.modelData.active; onToggled: v => Network.setVpn(vpn.modelData.name, v) }
                    }
                }
            }

            // Wi-Fi
            ColumnLayout {
                Layout.fillWidth: true
                visible: Network.wifiPresent
                spacing: 8
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    SectionLabel { Layout.fillWidth: true; text: Network.scanning ? "Wi-Fi · scanning…" : "Wi-Fi" }
                    Pill { visible: Network.wifiOn; label: "Rescan"; onClicked: Network.scan() }
                    Switch { checked: Network.wifiOn; onToggled: v => Network.setWifi(v) }
                }

                Text {
                    visible: Network.wifiOn && Network.networks.length === 0 && !Network.scanning
                    text: "No networks found"
                    color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                }

                Column {
                    Layout.fillWidth: true
                    visible: Network.wifiOn
                    spacing: 2
                    Repeater {
                        model: Network.networks.slice(0, 8)
                        delegate: Column {
                            id: net
                            required property var modelData
                            width: parent.width
                            spacing: 4

                            Rectangle {
                                width: parent.width; height: 36
                                radius: Theme.radiusSmall + 2
                                color: net.modelData.active ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Icon {
                                    id: sig
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: ""; size: 14
                                    opacity: [0.35, 0.55, 0.8, 1][Math.max(0, Math.min(3, Math.round(net.modelData.signal / 33.4)))]
                                    color: net.modelData.active ? Theme.accent : Theme.fg
                                }
                                Text {
                                    anchors { left: sig.right; leftMargin: 10; right: lock.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    elide: Text.ElideRight
                                    text: net.modelData.ssid + (Network.busySsid === net.modelData.ssid ? "  …" : "")
                                    color: net.modelData.active ? Theme.fg : Theme.fgDim
                                    font { family: Theme.font; pixelSize: Theme.fontSize }
                                }
                                Icon {
                                    id: lock
                                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: net.modelData.active ? "" : (net.modelData.secured ? "" : "")
                                    size: 11; color: net.modelData.active ? Theme.accent : Theme.fgDim
                                }
                                MouseArea {
                                    id: ma
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) { if (net.modelData.saved) Network.forget(net.modelData.ssid); return }
                                        if (net.modelData.active) return
                                        if (!net.modelData.saved && net.modelData.secured) {
                                            root.asking = root.asking === net.modelData.ssid ? "" : net.modelData.ssid
                                            if (root.asking !== "") pw.forceActiveFocus()
                                        } else Network.connect(net.modelData, "")
                                    }
                                }
                            }

                            // password for a new secured network
                            Rectangle {
                                visible: root.asking === net.modelData.ssid
                                width: parent.width; height: visible ? 36 : 0
                                radius: Theme.radius
                                color: Theme.tint
                                border { width: 1; color: pw.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }
                                TextInput {
                                    id: pw
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    color: Theme.fg; clip: true
                                    selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                                    font { family: Theme.font; pixelSize: Theme.fontSize }
                                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                                    onAccepted: { Network.connect(net.modelData, text); text = ""; root.asking = "" }
                                    Keys.onEscapePressed: root.asking = ""
                                    Text {
                                        visible: pw.text === "" && !pw.activeFocus
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Password"; color: Theme.fgDim
                                        font { family: Theme.font; pixelSize: Theme.fontSize }
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: Network.wifiOn && Network.networks.some(n => n.saved)
                    text: "Right-click a saved network to forget it"
                    color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
                }
            }
        }
    }
}
