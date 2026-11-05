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
        readonly property string screenName: modelData.name      // cached: the screen object may already be gone on destruction
        onShownChanged: Shell.setWidgetsShown(screenName, shown)
        Component.onDestruction: Shell.setWidgetsShown(screenName, false)   // monitor unplugged while shown

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

                Pager {
                    id: view
                    x: body.pad; y: body.pad + bar.height + 14
                    width: body.width - body.pad * 2
                    height: currentPageHeight
                    index: Shell.widgetsTab
                    count: win.tabs.length
                    onSwiped: i => Shell.widgetsTab = i

                    MediaPage   { width: view.width; active: Shell.widgetsTab === 0 }
                    SystemPage  { width: view.width }
                    WeatherPage { width: view.width }
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
