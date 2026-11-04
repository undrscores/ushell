import Quickshell
import QtQuick
import "../config"

// An auto-hiding panel docked to a screen edge ("top" = centered along the top,
// "left"/"right" = centered along that side). Hidden, it only keeps a thin
// hover strip alive; the rest of the window is click-through. Hover (or `pinned`)
// slides the panel in; leaving slides it out after a short delay.
PanelWindow {
    id: win
    property string edge: "top"
    property bool pinned: false
    property real panelWidth: 300
    property real panelHeight: 300
    property int hotSize: 4
    default property alias content: panel.data

    property bool shown: false
    property real slide: shown ? 1 : 0
    Behavior on slide { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } }

    readonly property real gap: Theme.margin
    anchors { top: edge === "top"; left: edge === "left"; right: edge === "right" }
    implicitWidth: panelWidth + gap * 2
    implicitHeight: panelHeight + gap * 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: win.shown ? full : strip }

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

        // faint hint while hidden
        Rectangle {
            radius: 2
            color: Theme.fgDim
            opacity: (1 - win.slide) * 0.45
            width: win.edge === "top" ? 44 : 3
            height: win.edge === "top" ? 3 : 44
            x: win.edge === "top" ? (win.width - width) / 2 : (win.edge === "left" ? 0 : win.width - width)
            y: win.edge === "top" ? 0 : (win.height - height) / 2
        }

        Glass {
            id: panel
            width: win.panelWidth
            height: win.panelHeight
            opacity: Math.min(1, win.slide * 1.6)
            x: win.edge === "top"  ? win.gap
             : win.edge === "left" ? -width + (width + win.gap) * win.slide
             :                       win.width - win.gap - width + (width + win.gap) * (1 - win.slide)
            y: win.edge === "top"  ? -height + (height + win.gap) * win.slide : win.gap
        }
    }

    // thin always-on trigger strip at the screen edge
    Item {
        id: strip
        width:  win.edge === "top" ? win.width : win.hotSize
        height: win.edge === "top" ? win.hotSize : win.height
        x: win.edge === "right" ? win.width - width : 0
        y: 0
    }
}
