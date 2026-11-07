import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// "Authentication required" dialog for polkit requests (see services/Auth.qml). It covers the screen the
// pointer is on, takes the keyboard while it is open, and goes away when the request is answered or cancelled.
PanelWindow {
    id: win
    readonly property bool open: Auth.active
    readonly property var flow: Auth.flow

    screen: Quickshell.screens.find(s => s.name === Wm.focusedOutput) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || card.opacity > 0.01

    WlrLayershell.namespace: "qs-auth"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) { input.text = ""; Qt.callLater(() => input.forceActiveFocus()) }
    // a wrong password: polkit asks again, the box is emptied and keeps the focus
    Connections {
        target: win.flow
        ignoreUnknownSignals: true
        function onSupplementaryMessageChanged() { input.text = ""; input.forceActiveFocus() }
        function onInputPromptChanged() { input.text = "" }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrimColor
        opacity: win.open ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }
        MouseArea { anchors.fill: parent }          // modal: nothing behind it takes clicks
    }

    Glass {
        id: card
        anchors.centerIn: parent
        width: 420
        height: col.implicitHeight + 40
        shadow: true
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        Behavior on scale { Spring { preset: win.open ? "popIn" : "popOut"; epsilon: 0.002 } }
        Behavior on height { Spring { preset: "settle"; epsilon: 0.4 } }

        ColumnLayout {
            id: col
            x: 20; y: 20; width: parent.width - 40
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: Theme.accentSoft
                    Icon { anchors.centerIn: parent; text: ""; size: 18; color: Theme.accent }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Authentication required"
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize + 3; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: win.flow ? win.flow.message : ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    }
                }
            }

            // which account, when polkit offers several
            Flow {
                Layout.fillWidth: true
                visible: win.flow && win.flow.identities && win.flow.identities.length > 1
                spacing: 6
                Repeater {
                    model: win.flow && win.flow.identities ? win.flow.identities : []
                    delegate: Pill {
                        required property var modelData
                        label: modelData.displayName ?? modelData.name ?? "account"
                        active: win.flow && win.flow.selectedIdentity === modelData
                        onClicked: win.flow.selectedIdentity = modelData
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: win.flow ? win.flow.supplementaryMessage : ""
                wrapMode: Text.Wrap
                color: win.flow && win.flow.supplementaryIsError ? Theme.danger : Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: Theme.radius
                color: Theme.tint
                border { width: 1; color: input.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }
                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: win.flow && win.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    color: Theme.fg; clip: true
                    selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 1 }
                    onAccepted: if (win.flow && text !== "") { Auth.submit(text); text = "" }
                    Keys.onEscapePressed: Auth.cancel()
                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.flow && win.flow.inputPrompt ? win.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                        color: Theme.fgDim; font: input.font
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Pill { label: "Cancel"; onClicked: Auth.cancel() }
                Pill { label: "Authenticate"; active: true; onClicked: input.accepted() }
            }
        }
    }
}
