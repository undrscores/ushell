import Quickshell
import Quickshell.Wayland
import QtQuick
import "../config"
import "../services"

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
    property bool alignTop: false       // left/right panels: sit in the top corner instead of the middle of the edge
    // Hover label drawn just outside the panel (e.g. an app name next to a dock icon).
    // tipY / tipX are positions along the panel's long / short axis, in window coordinates.
    property string tipText: ""
    property bool tipShown: false
    property real tipPos: 0
    property real panelWidth: 300       // desired size; animated into animW / animH
    property real panelHeight: 300
    property int hotSize: 4
    BackgroundEffect.blurRegion: Region { item: Prefs.frostedPanels ? panel : null; radius: win.panelRadius }
    property real panelRadius: Theme.radiusLarge
    default property alias content: body.data

    readonly property bool vertical: edge !== "top"
    readonly property real gap: Theme.edgeGap
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

        // The panel, moved and scaled as one.
        Item {
            id: pivot
            visible: win.slide > 0.002        // nothing renders or animates while hidden
            width: win.animW
            height: win.animH
            opacity: Math.max(0, Math.min(1, win.slide * 1.6))
            // grows out of the screen edge
            scale: 0.86 + 0.14 * Math.max(0, Math.min(1.15, win.slide))
            transformOrigin: win.edge === "top" ? Item.Top : (win.edge === "left" ? Item.Left : (win.alignTop ? Item.TopRight : Item.Right))
            x: win.edge === "top"  ? (win.width - width) / 2
             : win.edge === "left" ? -width + (width + win.gap) * win.slide
             :                       win.width - win.gap - width + (width + win.gap) * (1 - win.slide)
            y: win.edge === "top"  ? -height + (height + win.gap) * win.slide : (win.alignTop ? win.gap : (win.height - height) / 2)

            Glass {
                id: panel
                anchors.fill: parent
                radius: win.panelRadius

                Item { id: body; anchors.fill: parent }
            }

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
        height: win.vertical ? win.alongH + (win.alignTop ? win.gap + 2 : 0) : (win.shown ? win.animH + win.gap + 2 : win.hotSize)
        x: win.vertical ? (win.edge === "right" ? win.width - width : 0) : (win.width - width) / 2
        y: win.vertical && !win.alignTop ? (win.height - height) / 2 : 0
    }
}
