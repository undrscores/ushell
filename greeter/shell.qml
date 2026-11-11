import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Greetd
import QtQuick

// ushell login screen for greetd. Runs as the `greeter` user inside a throwaway uwc (see uwc.kdl and start.sh), so it
// can't read ~/.config: the colours come from theme.json and the wallpaper is a copy, both installed next
// to this file by install.sh (the shell writes the theme out as ~/.local/state/ushell/theme/greeter.json). The password goes to greetd -> PAM (/etc/pam.d/greetd), which is what unlocks
// the gnome-keyring "login" keyring, so apps like Proton VPN don't ask for it again.
ShellRoot {
    id: root
    readonly property string user: "@USER@"
    readonly property var session: ["sh", "-c", "exec /usr/local/bin/uwc-session"]
    readonly property string font: "JetBrains Mono"
    property var theme: ({})
    readonly property color bg: theme.bg || "#1e1e2e"
    readonly property color surface: theme.surface || "#313244"
    readonly property color fg: theme.fg || "#cdd6f4"
    readonly property color fgDim: theme.fgDim || "#7f849c"
    readonly property color accent: theme.accent || "#cba6f7"
    readonly property color danger: theme.danger || "#f38ba8"
    FileView {
        path: Qt.resolvedUrl("theme.json")
        onLoaded: { try { root.theme = JSON.parse(text()) } catch (e) {} }
    }
    Process { id: power }

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

            Row {
                anchors { right: parent.right; bottom: parent.bottom; margins: 24 }
                spacing: 10
                Repeater {
                    model: [ { icon: "⏻", cmd: "poweroff", tip: "Shut down" }, { icon: "↻", cmd: "reboot", tip: "Restart" } ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 40; height: 40; radius: 20
                        color: ma.containsMouse ? root.accent : root.bg
                        border { width: 1; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3) }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 18; color: ma.containsMouse ? root.bg : root.fg }
                        MouseArea {
                            id: ma; anchors.fill: parent; hoverEnabled: true
                            onClicked: { power.command = ["systemctl", modelData.cmd]; power.running = true }
                        }
                    }
                }
            }

            Column {
                id: content
                anchors.centerIn: parent
                opacity: 0
                NumberAnimation on opacity { to: 1; duration: 450; easing.type: Easing.OutQuad }
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm"); color: root.fg
                    font { family: root.font; pixelSize: 96; weight: Font.Light }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); color: root.fgDim
                    font { family: root.font; pixelSize: 20 }
                }
                Item { width: 1; height: 28 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.user; color: root.fg; font { family: root.font; pixelSize: 18 }
                }
                Item { width: 1; height: 4 }
                Rectangle {
                    id: box
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 300; height: 46; radius: 23
                    color: root.bg
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
                        font { family: root.font; pixelSize: 18 }
                        onAccepted: root.submit(text)
                        onTextChanged: if (text !== "") root.failed = false
                        Component.onCompleted: forceActiveFocus()
                        Text {
                            visible: input.text === ""
                            anchors.centerIn: parent
                            text: root.busy ? "Signing in…" : "Password"
                            color: root.fgDim; font { family: root.font; pixelSize: 16 }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 20
                    text: root.message !== "" ? root.message : (root.failed ? "Wrong password" : "")
                    color: root.danger; font { family: root.font; pixelSize: 13 }
                }
            }
        }
    }
}
