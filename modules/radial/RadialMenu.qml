import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Radial quick-action menu in the bottom right corner. Pushing the pointer into the corner makes a round
// button spring out of the screen edge, and four actions fan out around it. (Config: radialMenu)
Variants {
    model: Config.radialMenu ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property real inset: Theme.edgeGap
        readonly property real orbit: 112            // distance of the actions from the centre button
        readonly property real hub: 52               // centre button diameter
        // where the centre button sits when open
        readonly property real cx: width - inset - hub / 2 - 4
        readonly property real cy: height - inset - hub / 2 - 4

        readonly property var actions: [
            { glyph: "", label: "Calendar",   run: () => Shell.toggle("calendar") },
            { glyph: "", label: "Stats",      run: () => Actions.widgetsTab(1) },
            { glyph: "", label: "Wallpapers", run: () => Shell.toggle("wallpapers") },
            { glyph: "", label: "Power",      run: () => Shell.toggle("power") }
        ]

        anchors { bottom: true; right: true }
        implicitWidth: 330
        implicitHeight: 330
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: hitbox }

        WlrLayershell.namespace: "qs-radial"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        property bool shown: false
        property real slide: shown ? 1 : 0
        Behavior on slide { Spring { preset: win.shown ? "popIn" : "popOut"; epsilon: 0.003 } }

        readonly property bool want: hover.hovered && !suppress.running
        onWantChanged: { if (want) { hideTimer.stop(); showTimer.restart() } else { showTimer.stop(); hideTimer.restart() } }
        Timer { id: showTimer; interval: 110; onTriggered: win.shown = true }
        Timer { id: hideTimer; interval: 420; onTriggered: win.shown = false }
        Timer { id: suppress; interval: 700 }          // after choosing an action, don't pop straight back open

        Item {
            anchors.fill: parent
            HoverHandler { id: hover }

            // centre button
            Rectangle {
                id: centre
                width: win.hub; height: win.hub; radius: width / 2
                visible: win.slide > 0.002
                color: Theme.accent
                border { width: 2; color: Theme.frameColor }
                // springs in from beyond the corner
                x: win.cx - width / 2 + (1 - Math.min(1.15, win.slide)) * 90
                y: win.cy - height / 2 + (1 - Math.min(1.15, win.slide)) * 90
                scale: centreMa.containsMouse ? 1.08 : 1
                Behavior on scale { Spring { preset: "snap"; epsilon: 0.002 } }
                rotation: win.slide * 180
                Icon { anchors.centerIn: parent; text: ""; color: Theme.accentFg; rotation: -parent.rotation * 0 }
                MouseArea { id: centreMa; anchors.fill: parent; hoverEnabled: true }
            }

            Repeater {
                model: win.actions
                delegate: Item {
                    id: item
                    required property var modelData
                    required property int index
                    // evenly spaced along the quarter circle from "left" to "up"
                    readonly property real theta: (180 - 6 - index * 28) * Math.PI / 180
                    // staggered pop-out
                    property real appear: win.shown ? 1 : 0
                    Behavior on appear { SequentialAnimation {
                        PauseAnimation { duration: win.shown ? 40 + item.index * 55 : 0 }
                        NumberAnimation { duration: win.shown ? 520 : 130; easing.type: win.shown ? Easing.OutBack : Easing.InQuad; easing.overshoot: 2.6 }
                    } }
                    visible: appear > 0.01
                    opacity: Math.min(1, appear * 1.4)
                    width: 44; height: 44
                    x: win.cx - width / 2 + Math.cos(theta) * win.orbit * appear
                    y: win.cy - height / 2 - Math.sin(theta) * win.orbit * appear
                    scale: (ima.pressed ? 0.9 : (ima.containsMouse ? 1.14 : 1)) * (0.4 + 0.6 * Math.min(1, appear))
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.5 } }

                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        color: ima.containsMouse ? Theme.accent : Theme.frameColor
                        border { width: 1; color: Theme.line }
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                    Icon { anchors.centerIn: parent; text: item.modelData.glyph; color: ima.containsMouse ? Theme.accentFg : Theme.fg }

                    // label to the left of the button
                    Rectangle {
                        anchors { right: parent.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        width: lbl.implicitWidth + 20; height: 28; radius: 14
                        color: Theme.frameColor
                        border { width: 1; color: Theme.line }
                        // only the button under the pointer shows its name
                        opacity: ima.containsMouse ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                        Text { id: lbl; anchors.centerIn: parent; text: item.modelData.label; color: ima.containsMouse ? Theme.accent : Theme.fg
                               font { family: Theme.font; pixelSize: Theme.fontSize - 1; bold: true } }
                    }
                    MouseArea {
                        id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { item.modelData.run(); suppress.restart(); win.shown = false }
                    }
                }
            }
        }

        // Input: only the corner while closed; the whole fan while open.
        Item {
            id: hitbox
            width: win.shown ? win.width : 26
            height: win.shown ? win.height : 26
            x: win.width - width
            y: win.height - height
        }
    }
}
