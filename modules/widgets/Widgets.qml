import Quickshell
import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Right auto-hiding widgets panel: Media / System / Weather tabs you can click,
// wheel over, or swipe between. The panel resizes to fit the current tab.
// Mod+A pins it open.
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "right"
        pinned: Shell.widgetsPinned
        panelWidth: 340
        // Remember the last real height: the content only exists while shown, and a
        // collapsed (0) height would leave the hover strip with no area.
        property real lastHeight: 380
        panelHeight: loader.item ? loader.item.implicitHeight : lastHeight
        Connections {
            target: loader.item
            function onImplicitHeightChanged() { if (loader.item) win.lastHeight = loader.item.implicitHeight }
        }
        onShownChanged: Shell.widgetsShown = shown

        readonly property var tabs: [
            { icon: "", label: "Media" },
            { icon: "", label: "System" },
            { icon: "", label: "Weather" }
        ]

        // Content only exists while the panel is on screen: no hidden animations, no polling.
        Loader {
            id: loader
            anchors.fill: parent
            active: win.shown || win.slide > 0.002
            sourceComponent: Item {
                id: body
                readonly property int pad: 20
                implicitHeight: pad + bar.height + 14 + view.height + pad

                TabBar {
                    id: bar
                    x: body.pad; y: body.pad
                    width: body.width - body.pad * 2
                    tabs: win.tabs
                    current: Shell.widgetsTab
                    onSelected: i => Shell.widgetsTab = i
                }

                Flickable {
                    id: view
                    x: body.pad; y: body.pad + bar.height + 14
                    width: body.width - body.pad * 2
                    height: pages.children[Math.min(Shell.widgetsTab, pages.children.length - 1)].implicitHeight
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: pages.width
                    contentHeight: height

                    // follow the selected tab; animate unless the user is dragging
                    contentX: Shell.widgetsTab * width
                    Behavior on contentX {
                        enabled: !view.dragging && !view.flicking
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }
                    onFlickStarted: cancelFlick()
                    onDragEnded: {
                        const frac = contentX / width - Shell.widgetsTab
                        let t = Shell.widgetsTab
                        if (frac > 0.2) t++
                        else if (frac < -0.2) t--
                        Shell.widgetsTab = Math.max(0, Math.min(win.tabs.length - 1, t))
                        contentX = Qt.binding(() => Shell.widgetsTab * view.width)
                    }

                    Row {
                        id: pages
                        MediaPage   { width: view.width; active: Shell.widgetsTab === 0 }
                        SystemPage  { width: view.width }
                        WeatherPage { width: view.width }
                    }
                }

                // fetch weather the first time (and when stale) the tab is shown
                Connections {
                    target: Shell
                    function onWidgetsTabChanged() { if (Shell.widgetsTab === 2) Weather.ensure() }
                }
                Component.onCompleted: if (Shell.widgetsTab === 2) Weather.ensure()
            }
        }
    }
}
