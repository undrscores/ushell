import Quickshell
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
    property bool pinned: false
    property real panelWidth: 300       // desired size; animated into animW / animH
    property real panelHeight: 300
    property int hotSize: 4
    property real panelRadius: Theme.radius + 4
    default property alias content: panel.data

    readonly property bool vertical: edge !== "top"
    readonly property real gap: Theme.margin
    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1080

    // size actually drawn (animated, clamped to the screen)
    property real animW: Math.min(panelWidth, screenW - gap * 2)
    property real animH: Math.min(panelHeight, screenH - gap * 2)
    property bool ready: false
    Timer { interval: 600; running: true; onTriggered: win.ready = true }
    Behavior on animW { enabled: win.ready; NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    Behavior on animH { enabled: win.ready; NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

    property bool shown: false
    property real slide: shown ? 1 : 0
    Behavior on slide {
        NumberAnimation {
            duration: win.shown ? 480 : 260
            easing.type: win.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.25
        }
    }

    // Window = fixed canvas big enough for the largest the panel can get.
    anchors { top: true; bottom: vertical; left: edge === "left"; right: edge === "right" }
    implicitWidth:  vertical ? Math.min(560, screenW * 0.4) : Math.min(1200, screenW)
    implicitHeight: vertical ? screenH : 120
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Input only where something is actually on screen.
    mask: Region { item: hitbox }

    readonly property bool want: hover.hovered || pinned
    onWantChanged: {
        if (want) { hideTimer.stop(); showTimer.restart() }
        else      { showTimer.stop(); hideTimer.restart() }
    }
    onPinnedChanged: if (pinned) { hideTimer.stop(); shown = true }
    Timer { id: showTimer; interval: 130; onTriggered: win.shown = true }
    Timer { id: hideTimer; interval: 450; onTriggered: win.shown = false }

    Item {
        id: full
        anchors.fill: parent
        HoverHandler { id: hover }

        // faint breathing hint while hidden
        Rectangle {
            id: hint
            radius: 2
            color: Theme.accent
            property real pulse: 0.5
            opacity: Math.max(0, 1 - win.slide) * pulse
            SequentialAnimation on pulse {
                running: !win.shown
                loops: Animation.Infinite
                NumberAnimation { to: 0.9; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.3; duration: 1400; easing.type: Easing.InOutSine }
            }
            width: win.vertical ? 3 : 44
            height: win.vertical ? 44 : 3
            x: win.vertical ? (win.edge === "left" ? 0 : win.width - width) : (win.width - width) / 2
            y: win.vertical ? (win.height - height) / 2 : 0
        }

        Glass {
            id: panel
            visible: win.slide > 0.002        // nothing renders or animates while hidden
            width: win.animW
            height: win.animH
            radius: win.panelRadius
            opacity: Math.min(1, win.slide * 1.6)
            x: win.edge === "top"  ? (win.width - width) / 2
             : win.edge === "left" ? -width + (width + win.gap) * win.slide
             :                       win.width - win.gap - width + (width + win.gap) * (1 - win.slide)
            y: win.edge === "top"  ? -height + (height + win.gap) * win.slide : (win.height - height) / 2
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
