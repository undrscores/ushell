import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"
import "../../services"

// Draws the chosen wallpaper behind everything, one window per screen (a screen can have its own picture:
// Prefs.monitorWallpapers). Nothing is created until a wallpaper has been chosen (or while the chosen one can't
// be loaded), so another wallpaper program keeps working if you prefer it.
Variants {
    id: root
    // a window per screen that has a picture to show (the main one, or its own)
    model: Quickshell.screens.filter(s => { const p = Wallpapers.pathFor(s.name); return p !== "" && Wallpapers.failed !== p })

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

        readonly property string wantedPath: Wallpapers.pathFor(screen ? screen.name : "")
        readonly property string wanted: Wallpapers.url(wantedPath)

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
                    console.warn("ushell wallpaper: can't load " + win.wantedPath)
                    Wallpapers.failed = win.wantedPath       // the windows go away; the Appearance panel says why
                }
            }
        }
        onWantedChanged: if (img.source.toString() !== wanted) { img.opacity = 0; swap.restart() }
        Timer { id: swap; interval: 420; onTriggered: img.source = win.wanted }
        Component.onCompleted: img.source = wanted
    }
}
