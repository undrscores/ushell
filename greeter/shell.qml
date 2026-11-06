import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick

// ushell login screen for greetd. Runs as the `greeter` user inside a throwaway niri (see niri.kdl), so it
// can't read ~/.config: the colours are fixed here (Catppuccin Mocha + mauve) and the wallpaper is a copy
// installed next to this file. The password goes to greetd -> PAM (/etc/pam.d/greetd), which is what unlocks
// the gnome-keyring "login" keyring, so apps like Proton VPN don't ask for it again.
ShellRoot {
    id: root
    readonly property string user: "@USER@"
    readonly property var session: ["niri-session"]
    readonly property color bg: "#1e1e2e"
    readonly property color fg: "#cdd6f4"
    readonly property color fgDim: "#7f849c"
    readonly property color accent: "#cba6f7"
    readonly property color danger: "#f38ba8"

    property bool busy: false
    property bool failed: false
    property string message: ""
    property string pending: ""

    function submit(password) {
        if (busy || password === "") return
        pending = password; busy = true; failed = false; message = ""
        Greetd.createSession(user)
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) { Greetd.respond(root.pending); root.pending = "" }
            else if (error) root.message = message
            else Greetd.respond("")
        }
        function onAuthFailure(message) { root.pending = ""; root.busy = false; root.failed = true; root.message = message }
        function onReadyToLaunch() { Greetd.launch(root.session, [], true) }
        function onError(error) { root.pending = ""; root.busy = false; root.failed = true; root.message = error }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: root.bg

            SystemClock { id: clock; precision: SystemClock.Seconds }
            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("wallpaper.jpg")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.55 }

            Column {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm"); color: root.fg
                    font { pixelSize: 96; weight: Font.Light }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); color: root.fgDim
                    font.pixelSize: 20
                }
                Item { width: 1; height: 28 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.user; color: root.fg; font.pixelSize: 18
                }
                Item { width: 1; height: 4 }
                Rectangle {
                    id: box
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 300; height: 46; radius: 23
                    color: Qt.rgba(0.12, 0.12, 0.18, 0.7)
                    border { width: 1; color: root.failed ? root.danger : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, input.activeFocus ? 0.6 : 0.2) }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                        NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                        NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
                    }
                    Connections { target: root; function onFailedChanged() { if (root.failed) { shake.restart(); input.text = "" } } }
                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        enabled: !root.busy
                        focus: true
                        color: root.fg
                        font.pixelSize: 18
                        onAccepted: root.submit(text)
                        onTextChanged: if (text !== "") root.failed = false
                        Component.onCompleted: forceActiveFocus()
                        Text {
                            visible: input.text === ""
                            anchors.centerIn: parent
                            text: root.busy ? "Signing in…" : "Password"
                            color: root.fgDim; font.pixelSize: 16
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 20
                    text: root.message !== "" ? root.message : (root.failed ? "Wrong password" : "")
                    color: root.danger; font.pixelSize: 14
                }
            }
        }
    }
}
