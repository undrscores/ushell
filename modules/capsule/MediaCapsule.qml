import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../config"
import "../../services"
import "../../components"

// Now-playing capsule on the bottom edge, growing out of the frame at the bottom left. It slides up when the
// pointer reaches the bottom-left corner, and for a few seconds whenever the track changes. The cover spins
// while music plays. (Config: mediaCapsule)
Variants {
    model: Config.mediaCapsule ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool attached: Theme.frame > 0
        readonly property real inset: Theme.edgeGap
        readonly property real fillet: 14

        anchors { bottom: true; left: true }
        margins { left: Theme.frame + 28 }
        implicitWidth: 520
        implicitHeight: 150
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: Media.available
        mask: Region { item: hitbox }

        WlrLayershell.namespace: "qs-capsule"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        property bool shown: false
        property real slide: shown ? 1 : 0
        Behavior on slide { Spring { preset: win.shown ? "popIn" : "popOut"; epsilon: 0.003 } }

        readonly property bool want: hover.hovered || flash.running
        onWantChanged: { if (want) { hideTimer.stop(); showTimer.restart() } else { showTimer.stop(); hideTimer.restart() } }
        Timer { id: showTimer; interval: 120; onTriggered: win.shown = true }
        Timer { id: hideTimer; interval: 500; onTriggered: win.shown = false }

        // peek for a moment when the track changes, on the monitor you are working on only
        readonly property bool onFocusedOutput: Niri.focusedOutput === "" || (screen !== null && screen.name === Niri.focusedOutput)
        Timer { id: flash; interval: 4500 }
        Connections {
            target: Media
            function onTitleChanged() { if (Media.title !== "" && Media.available && win.onFocusedOutput) flash.restart() }
        }

        Item {
            anchors.fill: parent
            HoverHandler { id: hover }

            Item {
                id: pivot
                visible: win.slide > 0.002
                width: row.implicitWidth + 40
                height: 72
                x: win.fillet
                y: win.height - (win.inset + height) * Math.min(1.1, win.slide)
                opacity: Math.max(0, Math.min(1, win.slide * 1.6))
                transformOrigin: Item.Bottom
                scale: 0.88 + 0.12 * Math.max(0, Math.min(1.1, win.slide))

                Glass {
                    anchors.fill: parent
                    radius: Theme.radiusLarge
                    flat: win.attached
                    color: win.attached ? Theme.frameColor : Theme.glass
                    border.width: win.attached ? 0 : 1
                    bottomLeftRadius: win.attached ? 0 : Theme.radiusLarge
                    bottomRightRadius: win.attached ? 0 : Theme.radiusLarge
                }
                // clicking the capsule opens the full player
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Shell.toggle("media")
                }
                // concave corners where the capsule meets the frame
                Fillet { visible: win.attached; r: win.fillet; x: -r;          y: pivot.height - r; cx: r; cy: r }
                Fillet { visible: win.attached; r: win.fillet; x: pivot.width; y: pivot.height - r; cx: 0; cy: r }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 14

                    // cover: a disc that turns while the music plays
                    Item {
                        width: 52; height: 52
                        anchors.verticalCenter: parent.verticalCenter
                        Item {
                            id: discMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle { anchors.fill: parent; radius: width / 2 }
                        }
                        Item {
                            id: disc
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: discMask }
                            Rectangle { anchors.fill: parent; color: Theme.tint }
                            Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            Icon { anchors.centerIn: parent; visible: Media.art === ""; text: ""; color: Theme.fgDim }
                            // turns while playing and keeps its angle when paused
                            Timer {
                                interval: 33; repeat: true
                                running: pivot.visible && Media.playing
                                onTriggered: disc.rotation = (disc.rotation + 0.85) % 360
                            }
                        }
                        // spindle hole, like a record
                        Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: Theme.frameColor
                                    border { width: 1; color: Theme.line } }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Marquee { width: 190; text: Media.artist; color: Theme.accent; pixelSize: Theme.fontSize - 2; running: pivot.visible }
                        Marquee { width: 190; text: Media.title; color: Theme.fg; pixelSize: Theme.fontSize + 1; bold: true; running: pivot.visible }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: [
                                { glyph: "", act: 0 },
                                { glyph: "", act: 1 },
                                { glyph: "", act: 2 }
                            ]
                            delegate: Item {
                                id: btn
                                required property var modelData
                                width: 34; height: 34
                                scale: bma.pressed ? 0.88 : (bma.containsMouse ? 1.15 : 1)
                                Behavior on scale { Spring { preset: "snap"; epsilon: 0.002 } }
                                Rectangle { anchors.fill: parent; radius: width / 2; color: bma.containsMouse ? Theme.hover : "transparent"
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } } }
                                Icon {
                                    anchors.centerIn: parent
                                    text: btn.modelData.act === 1 ? (Media.playing ? "" : "") : btn.modelData.glyph
                                    color: btn.modelData.act === 1 ? Theme.accent : (bma.containsMouse ? Theme.fg : Theme.fgDim)
                                }
                                MouseArea {
                                    id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (btn.modelData.act === 0) Media.prev(); else if (btn.modelData.act === 1) Media.toggle(); else Media.next() }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Input: a thin strip along the bottom while hidden, the whole capsule (and its fillets) while shown.
        Item {
            id: hitbox
            x: win.shown ? win.fillet - 4 : win.fillet
            width: win.shown ? pivot.width + 8 : Math.min(260, pivot.width)
            height: win.shown ? win.inset + pivot.height + 6 : 5
            y: win.height - height
        }
    }
}
