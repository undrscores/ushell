import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Settings dropdown (gear in the top pill, or `qs ipc call shell toggle settings`).
Overlay {
    id: root
    name: "settings"

    DropCard {
        id: card
        open: root.open
        contentWidth: 340
        contentHeight: col.implicitHeight

        component Row_: RowLayout {
            id: r
            property string title
            property string hint
            property string icon
            default property alias control: slot.data
            Layout.fillWidth: true
            spacing: 12
            Icon {
                visible: r.icon !== ""
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 24; Layout.topMargin: 1
                text: r.icon; size: 16; color: Theme.accent
            }
            Column {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2
                Text { width: parent.width; wrapMode: Text.Wrap; text: r.title; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize } }
                Text { width: parent.width; wrapMode: Text.Wrap; visible: r.hint !== ""; text: r.hint; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
            }
            Item { id: slot; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
        }

        // "HH:MM" box: saves when you press Enter or leave it, and only if it is a valid time
        component TimeField_: Rectangle {
            id: tf
            property string value
            signal edited(string v)
            implicitWidth: 64; implicitHeight: 30
            radius: Theme.radiusSmall + 2
            color: Theme.tint
            border { width: 1; color: ti.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }
            TextInput {
                id: ti
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                color: Theme.fg; clip: true; text: tf.value
                inputMask: "99:99"
                selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                font { family: Theme.font; pixelSize: Theme.fontSize }
                function commit() { if (/^([01]\d|2[0-3]):[0-5]\d$/.test(text)) tf.edited(text); else text = tf.value }
                onAccepted: { commit(); focus = false }
                onActiveFocusChanged: if (!activeFocus) commit()
                Keys.onEscapePressed: Shell.close()
            }
        }

        ColumnLayout {
            id: col
            x: card.padding; y: card.padding; width: card.contentWidth
            spacing: 14

            SectionLabel { text: "Panels" }
            Row_ {
                icon: "\uf2d0"; title: "Auto-hide top pill"; hint: "Off keeps it visible and reserves space"
                Switch { checked: Prefs.topAutoHide; onToggled: v => Prefs.set("topAutoHide", v) }
            }
            Row_ {
                icon: "\uf0c9"; title: "Auto-hide left dock"; hint: "Off keeps it visible and reserves space"
                Switch { checked: Prefs.leftAutoHide; onToggled: v => Prefs.set("leftAutoHide", v) }
            }
            Row_ {
                icon: ""; title: "Screen frame"; hint: "A border around the screen that the bar, dock and menus grow out of"
                Switch { checked: Prefs.frame; onToggled: v => Prefs.set("frame", v) }
            }
            Row_ {
                icon: ""; title: "Now-playing capsule"; hint: "Slides up at the bottom left on hover and when the track changes"
                Switch { checked: Prefs.mediaCapsule; onToggled: v => Prefs.set("mediaCapsule", v) }
            }
            Row_ {
                icon: ""; title: "Radial menu"; hint: "Quick actions from the bottom right corner"
                Switch { checked: Prefs.radialMenu; onToggled: v => Prefs.set("radialMenu", v) }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
            SectionLabel { text: "Appearance" }
            Row_ {
                icon: "\uf1fc"; title: "Theme and wallpaper"
                hint: (Theme.mode === "light" ? "Light" : "Dark") + " · " + (Wallpapers.useColors ? "colours from the wallpaper" : Theme.accentName)
                Pill { label: "Open"; onClicked: Shell.open("appearance") }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
            SectionLabel { text: "Weather" }
            Row_ {
                icon: "\uf2c9"; title: "Metric units"; hint: "°C and km/h instead of °F and mph"
                Switch { checked: Prefs.weatherMetric; onToggled: v => Prefs.set("weatherMetric", v) }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.radius
                color: Theme.tint
                border { width: 1; color: city.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }
                TextInput {
                    id: city
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                    clip: true
                    text: Prefs.weatherCity
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    onAccepted: focus = false                       // leaving the field is what saves it
                    onActiveFocusChanged: if (!activeFocus) Prefs.set("weatherCity", text.trim())
                    Keys.onEscapePressed: Shell.close()
                    Text { visible: !city.text; text: "City (empty = detect by IP)"; color: Theme.fgDim; font: city.font; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
            SectionLabel { text: "Notifications" }
            Row_ {
                icon: "\uf186"; title: "Quiet hours"; hint: "Do Not Disturb every day in this window (urgent ones still show)"
                Switch { checked: Prefs.dndSchedule; onToggled: v => Prefs.set("dndSchedule", v) }
            }
            RowLayout {
                visible: Prefs.dndSchedule
                Layout.fillWidth: true
                spacing: 10
                Text { text: "From"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
                TimeField_ { value: Prefs.dndFrom; onEdited: v => Prefs.set("dndFrom", v) }
                Text { text: "to"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
                TimeField_ { value: Prefs.dndTo; onEdited: v => Prefs.set("dndTo", v) }
                Item { Layout.fillWidth: true }
            }
            ColumnLayout {
                visible: Prefs.mutedApps.length > 0
                Layout.fillWidth: true
                spacing: 6
                Text { text: "Muted apps (no popups, still in the history)"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 3 } }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: Prefs.mutedApps
                        delegate: Pill { required property string modelData; label: modelData + "  \uf00d"; onClicked: Notifications.unmute(modelData) }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
            SectionLabel { text: "Idle" }
            Row_ {
                icon: "\uf023"; title: "Lock after"; hint: "Of no keyboard or mouse use; a playing video holds it back"
                Row {
                    spacing: 4
                    Repeater {
                        model: [0, 5, 10, 30]
                        delegate: Pill { required property int modelData; label: modelData === 0 ? "Off" : modelData + "m"; active: Prefs.idleLockMin === modelData
                                         onClicked: Prefs.set("idleLockMin", modelData) }
                    }
                }
            }
            Row_ {
                icon: "\uf108"; title: "Screens off after"
                Row {
                    spacing: 4
                    Repeater {
                        model: [0, 5, 15, 30]
                        delegate: Pill { required property int modelData; label: modelData === 0 ? "Off" : modelData + "m"; active: Prefs.idleOffMin === modelData
                                         onClicked: Prefs.set("idleOffMin", modelData) }
                    }
                }
            }
            Row_ {
                icon: "\uf0f4"; title: "Keep awake"; hint: "No lock or screen-off until you turn it off or restart the shell"
                Switch { checked: Idle.keepAwake; onToggled: v => Idle.keepAwake = v }
            }
        }
    }
}
