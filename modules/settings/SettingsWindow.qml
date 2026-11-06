import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// The settings window: a window of its own (not a popup) with a sidebar of sections.
// Open it from the radial menu, the launcher, or `qs ipc call shell toggle settings`
// (`... toggle appearance` jumps to the Appearance section).
FloatingWindow {
    id: win
    title: "usettings"
    visible: Shell.settingsOpen
    onVisibleChanged: if (!visible) Shell.settingsOpen = false      // closed from the compositor
    implicitWidth: 960
    implicitHeight: 660
    minimumSize: Qt.size(720, 480)
    color: Theme.bg

    readonly property var sections: [
        { id: "general",       label: "General",         icon: "" },
        { id: "appearance",    label: "Appearance",      icon: "" },
        { id: "notifications", label: "Notifications",   icon: "" },
        { id: "power",         label: "Power and idle",  icon: "" },
        { id: "weather",       label: "Weather",         icon: "" },
        { id: "about",         label: "About",           icon: "" }
    ]
    readonly property var current: sections.find(s => s.id === Shell.settingsPage) ?? sections[0]

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Shell.settingsOpen = false

        // ── sidebar ─────────────────────────────────────────────────────────
        Rectangle {
            id: side
            width: 230
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            color: Theme.surface
            Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: Theme.line }

            Text {
                x: 24; y: 24
                text: "usettings"
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize + 6; bold: true }
            }

            Column {
                x: 12; y: 76
                width: side.width - 24
                spacing: 4
                Repeater {
                    model: win.sections
                    delegate: Rectangle {
                        id: item
                        required property var modelData
                        readonly property bool active: Shell.settingsPage === modelData.id
                        width: parent.width; height: 42
                        radius: Theme.radiusSmall + 2
                        color: active ? Theme.accentSoft : (ima.containsMouse ? Theme.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Rectangle {          // marker on the chosen section
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 3; radius: 1.5
                            height: item.active ? 20 : 0
                            color: Theme.accent
                            Behavior on height { Spring { preset: "snap"; epsilon: 0.3 } }
                        }
                        Row {
                            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Icon { anchors.verticalCenter: parent.verticalCenter; width: 22; text: item.modelData.icon; size: 16; color: item.active ? Theme.accent : Theme.fgDim }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: item.modelData.label
                                color: item.active ? Theme.fg : Theme.fgDim
                                font { family: Theme.font; pixelSize: Theme.fontSize + 1; bold: item.active }
                            }
                        }
                        MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.settingsPage = item.modelData.id }
                    }
                }
            }
        }

        // ── page ────────────────────────────────────────────────────────────
        Item {
            anchors { top: parent.top; bottom: parent.bottom; left: side.right; right: parent.right }

            Text {
                id: heading
                x: 36; y: 24
                text: win.current.label
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize + 8; bold: true }
            }

            Flickable {
                id: scroller
                anchors { top: heading.bottom; topMargin: 20; bottom: parent.bottom; left: parent.left; right: parent.right }
                contentWidth: width
                contentHeight: pageHolder.height + 40
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Item {
                    id: pageHolder
                    x: 36
                    width: Math.min(720, scroller.width - 72)
                    height: loader.item ? loader.item.implicitHeight : 0

                    Loader {
                        id: loader
                        width: parent.width
                        sourceComponent: ({ general: general, appearance: appearance, notifications: notifications,
                                            power: power, weather: weather, about: about })[win.current.id]
                        // a short fade when switching sections
                        onLoaded: { opacity = 0; fade.restart(); scroller.contentY = 0 }
                        NumberAnimation { id: fade; target: loader; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Theme.easing }
                    }
                }
            }
        }

        Component { id: general;       GeneralSettings {} }
        Component { id: appearance;    AppearanceSettings {} }
        Component { id: notifications; NotificationSettings {} }
        Component { id: power;         PowerSettings {} }
        Component { id: weather;       WeatherSettings {} }
        Component { id: about;         AboutSettings {} }
    }
}
