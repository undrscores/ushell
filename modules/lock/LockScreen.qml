import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"

// The lock screen: one surface per screen while Lock.locked is true (the compositor hides everything else
// and only lets this program take input). The wallpaper, dimmed, a clock, and a password field.
//
// If this process dies while locked the compositor keeps the session locked; restart `qs` to get the
// prompt back (or log in on another TTY and run `pkill niri`).
Scope {
    // Not a binding: if the compositor refuses or ends the lock, `locked` is reset on the lock and Lock must follow.
    Connections { target: Lock; function onLockedChanged() { if (lock.locked !== Lock.locked) lock.locked = Lock.locked } }

// WlSessionLock's one child is the template for the per-screen surface, so nothing else may be put inside it.
WlSessionLock {
    id: lock
    onLockedChanged: if (Lock.locked !== locked) Lock.locked = locked

    WlSessionLockSurface {
        id: surface
        color: Theme.bg

        SystemClock { id: clock; precision: SystemClock.Seconds }

        Image {
            anchors.fill: parent
            source: Prefs.wallpaper !== "" ? Wallpapers.url(Prefs.wallpaper) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(surface.width, surface.height)
        }
        Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.55 }

        Column {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.fg
                font { family: Theme.font; pixelSize: 96; weight: Font.Light }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: 20 }
            }
            Item { width: 1; height: 28 }

            Rectangle {
                id: box
                anchors.horizontalCenter: parent.horizontalCenter
                width: 300; height: 46; radius: 23
                color: Theme.glass
                border { width: 1; color: Lock.failed ? Theme.danger : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, input.activeFocus ? 0.6 : 0.2) }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                // a wrong password shakes the box
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -8; duration: 60 }
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
                }
                Connections { target: Lock; function onAttemptsChanged() { if (Lock.attempts > 0) { shake.restart(); input.text = "" } } }

                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    enabled: !Lock.checking
                    focus: true
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 18 }
                    onAccepted: Lock.submit(text)
                    onTextChanged: if (text !== "") Lock.failed = false
                    Component.onCompleted: forceActiveFocus()
                    Text {
                        visible: input.text === ""
                        anchors.centerIn: parent
                        text: Lock.checking ? "Checking…" : "Password"
                        color: Theme.fgDim
                        font { family: Theme.font; pixelSize: 16 }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 20
                text: Lock.message !== "" ? Lock.message : (Lock.failed ? "Wrong password" + (Lock.attempts > 1 ? "  (" + Lock.attempts + ")" : "") : "")
                color: Theme.danger
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }
    }
}
}
