import Quickshell
import Quickshell.Wayland
import QtQuick
import "../config"

// An auto-hiding panel docked to a screen edge ("top" = centered along the top,
// "left"/"right" = centered along that side).
//
// The window itself is a fixed, click-through canvas. The visible panel inside it
// follows panelWidth / panelHeight (usually bound to the content's implicit size)
// and animates between sizes, so content can come and go without ugly gaps.
// Hidden, only a thin hover strip is live and the panel isn't rendered at all.
PanelWindow {
    id: win
    property string edge: "top"
    property bool pinned: false         // temporarily held open (e.g. a menu is using it)
    property bool autoHide: true        // false = always shown, and it reserves its space
    property bool takesFocus: false     // allow keyboard focus on click (for text fields)
    // Hover label drawn just outside the panel (e.g. an app name next to a dock icon).
    // tipY / tipX are positions along the panel's long / short axis, in window coordinates.
    property string tipText: ""
    property bool tipShown: false
    property real tipPos: 0
    property real panelWidth: 300       // desired size; animated into animW / animH
    property real panelHeight: 300
    property int hotSize: 4
    property real panelRadius: Theme.radiusLarge
    default property alias content: body.data

    readonly property bool vertical: edge !== "top"
    readonly property bool attached: Theme.frame > 0     // flush with the screen frame, with concave fillets where they meet
    readonly property real gap: Theme.edgeGap
    readonly property real fillet: 14
    readonly property real bleed: 3                     // how far an attached panel reaches under the frame
    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1080

    // size actually drawn (animated, clamped to the screen)
    property real animW: Math.min(panelWidth, screenW - gap * 2)
    property real animH: Math.min(panelHeight, screenH - gap * 2)
    property bool ready: false
    Timer { interval: 600; running: true; onTriggered: win.ready = true }
    // size changes wobble a little before settling
    Behavior on animW { enabled: win.ready; Spring { preset: "settle"; epsilon: 0.4 } }
    Behavior on animH { enabled: win.ready; Spring { preset: "settle"; epsilon: 0.4 } }

    property bool shown: false
    property real slide: shown ? 1 : 0
    // Real spring physics: bouncy on the way in, quick and tight on the way out.
    Behavior on slide {
        Spring { preset: win.shown ? "popIn" : "popOut"; epsilon: 0.003 }
    }

    // Window = fixed canvas big enough for the largest the panel can get.
    anchors { top: true; bottom: vertical; left: edge === "left"; right: edge === "right" }
    implicitWidth:  vertical ? Math.min(560, screenW * 0.4) : Math.min(1200, screenW)
    implicitHeight: vertical ? screenH : 120
    // Always-shown panels push tiled windows out of their way; auto-hiding ones float over them.
    exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: autoHide ? 0 : (vertical ? panelWidth : panelHeight) + Theme.margin * 2
    WlrLayershell.keyboardFocus: takesFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"

    // Input only where something is actually on screen.
    mask: Region { item: hitbox }

    readonly property bool want: hover.hovered || pinned || !autoHide
    onWantChanged: {
        if (want) { hideTimer.stop(); showTimer.restart() }
        else      { showTimer.stop(); hideTimer.restart() }
    }
    onPinnedChanged: if (pinned) { hideTimer.stop(); shown = true }
    onAutoHideChanged: if (!autoHide) { hideTimer.stop(); shown = true }
    Component.onCompleted: if (!autoHide) shown = true
    Timer { id: showTimer; interval: 130; onTriggered: win.shown = true }
    Timer { id: hideTimer; interval: 450; onTriggered: win.shown = false }

    Item {
        id: full
        anchors.fill: parent
        HoverHandler { id: hover }

        // label bubble: sits on the open side of the panel and is never clipped by it
        Rectangle {
            id: tip
            visible: opacity > 0.01
            opacity: win.tipShown && win.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            height: tipLabel.implicitHeight + 14
            width: tipLabel.implicitWidth + 22
            radius: height / 2
            color: Theme.glass
            border { width: 1; color: Theme.line }
            readonly property real along: Math.max(0, win.tipPos - height / 2)
            x: win.edge === "left" ? pivot.x + pivot.width + 10 + 6 * (1 - opacity)
             : win.edge === "right" ? pivot.x - width - 10 - 6 * (1 - opacity)
             : Math.max(0, win.tipPos - width / 2)
            y: win.edge === "top" ? pivot.y + pivot.height + 10 + 6 * (1 - opacity) : along
            z: 5
            Text {
                id: tipLabel
                anchors.centerIn: parent
                text: win.tipText
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
        }

        // The panel plus its frame fillets, moved and scaled as one.
        Item {
            id: pivot
            visible: win.slide > 0.002        // nothing renders or animates while hidden
            width: win.animW
            height: win.animH
            opacity: Math.max(0, Math.min(1, win.slide * 1.6))
            // grows out of the screen edge
            scale: 0.86 + 0.14 * Math.max(0, Math.min(1.15, win.slide))
            transformOrigin: win.edge === "top" ? Item.Top : (win.edge === "left" ? Item.Left : Item.Right)
            x: win.edge === "top"  ? (win.width - width) / 2
             : win.edge === "left" ? -width + (width + win.gap) * win.slide
             :                       win.width - win.gap - width + (width + win.gap) * (1 - win.slide)
            y: win.edge === "top"  ? -height + (height + win.gap) * win.slide : (win.height - height) / 2

            Glass {
                id: panel
                // reaches a little under the frame so niri's window border (which pokes into the frame band)
                // and anti-aliasing don't show as a line where the panel meets the frame
                anchors {
                    fill: parent
                    topMargin:   win.attached && win.edge === "top"   ? -win.bleed : 0
                    leftMargin:  win.attached && win.edge === "left"  ? -win.bleed : 0
                    rightMargin: win.attached && win.edge === "right" ? -win.bleed : 0
                }
                radius: win.panelRadius
                flat: win.attached
                color: win.attached ? Theme.frameColor : Theme.glass
                border.width: win.attached ? 0 : 1
                // the side against the frame is square
                topLeftRadius:     win.attached && (win.edge === "top" || win.edge === "left")  ? 0 : win.panelRadius
                topRightRadius:    win.attached && (win.edge === "top" || win.edge === "right") ? 0 : win.panelRadius
                bottomLeftRadius:  win.attached && win.edge === "left"  ? 0 : win.panelRadius
                bottomRightRadius: win.attached && win.edge === "right" ? 0 : win.panelRadius

                // the panel's content keeps the size and position it would have without the bleed
                Item {
                    id: body
                    anchors {
                        fill: parent
                        topMargin:   win.attached && win.edge === "top"   ? win.bleed : 0
                        leftMargin:  win.attached && win.edge === "left"  ? win.bleed : 0
                        rightMargin: win.attached && win.edge === "right" ? win.bleed : 0
                    }
                }
            }

            // concave corners where the panel meets the frame
            Fillet { visible: win.attached && win.edge === "top";   r: win.fillet; x: -r;         y: 0;       cx: r; cy: 0 }
            Fillet { visible: win.attached && win.edge === "top";   r: win.fillet; x: pivot.width; y: 0;       cx: 0; cy: 0 }
            Fillet { visible: win.attached && win.edge === "left";  r: win.fillet; x: 0;          y: -r;      cx: 0; cy: r }
            Fillet { visible: win.attached && win.edge === "left";  r: win.fillet; x: 0;          y: pivot.height; cx: 0; cy: 0 }
            Fillet { visible: win.attached && win.edge === "right"; r: win.fillet; x: pivot.width - r; y: -r; cx: r; cy: r }
            Fillet { visible: win.attached && win.edge === "right"; r: win.fillet; x: pivot.width - r; y: pivot.height; cx: r; cy: 0 }
        }
    }

    // The one region that receives input. Hidden: a thin strip at the screen edge
    // (never smaller than minStrip along the edge, even if the content is empty).
    // Shown: the panel's final footprint plus the gap to the screen edge.
    // It is deliberately static (not tied to the sliding panel) so hover can't be lost mid-animation.
    readonly property real alongW: Math.max(win.animW, 160)
    readonly property real alongH: Math.max(win.animH, 160)
    Item {
        id: hitbox
        width:  win.vertical ? (win.shown ? win.animW + win.gap + 2 : win.hotSize) : win.alongW
        height: win.vertical ? win.alongH : (win.shown ? win.animH + win.gap + 2 : win.hotSize)
        x: win.vertical ? (win.edge === "right" ? win.width - width : 0) : (win.width - width) / 2
        y: win.vertical ? (win.height - height) / 2 : 0
    }
}
