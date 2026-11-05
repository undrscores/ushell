import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"

// Draws the chosen wallpaper behind everything, one window per screen. Nothing is created until a
// wallpaper has been chosen (or while the chosen one can't be loaded), so another wallpaper program
// keeps working if you prefer it.
Variants {
    id: root
    readonly property bool active: Prefs.wallpaper !== "" && Wallpapers.failed !== Prefs.wallpaper
    model: root.active ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "black"
        WlrLayershell.namespace: "ushell-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property string wanted: Wallpapers.url(Prefs.wallpaper)

        // a change fades the old picture out, then the new one in once it has loaded
        Image {
            id: img
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false                    // wallpapers are big; don't keep old ones in memory
            // decode at screen size, not at the picture's own (often 4K+) size
            sourceSize: Qt.size(Math.round(win.modelData.width * win.modelData.devicePixelRatio),
                                Math.round(win.modelData.height * win.modelData.devicePixelRatio))
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.InOutQuad } }
            onStatusChanged: {
                if (status === Image.Ready) opacity = 1
                else if (status === Image.Error && source.toString() === win.wanted) {
                    console.warn("ushell wallpaper: can't load " + Prefs.wallpaper)
                    Wallpapers.failed = Prefs.wallpaper      // the windows go away; the Appearance panel says why
                }
            }
        }
        onWantedChanged: if (img.source.toString() !== wanted) { img.opacity = 0; swap.restart() }
        Timer { id: swap; interval: 420; onTriggered: img.source = win.wanted }
        Component.onCompleted: img.source = wanted
    }
}
