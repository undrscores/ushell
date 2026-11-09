import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// The canvas as a map, with the zoom level and the saved viewpoints (bookmarks).
// Zoom indicator in the bar, or `qs ipc call shell toggle minimap`.
Overlay {
    id: root
    name: "minimap"
    readonly property var pinned: Uwm.pinnedOn(Uwm.focusedMon)

    DropCard {
        open: root.open
        contentWidth: 340
        contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            x: parent.padding; y: parent.padding; width: parent.contentWidth
            spacing: 10

            CanvasMap { Layout.fillWidth: true; Layout.preferredHeight: 210 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: Math.round(Uwm.zoom * 100) + "%"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 2; bold: true }
                }
                Pill { label: "Overview"; onClicked: Uwm.send("overview") }
                Pill { label: "Home"; onClicked: Uwm.send("home") }
                Pill { label: "100%"; onClicked: Uwm.zoomTo(1) }
            }

            // the HUD: windows pinned to the screen. Click to focus, x to unpin.
            SectionLabel { Layout.fillWidth: true; text: "Pinned to screen"; visible: pinned.length > 0 }
            Repeater {
                model: root.pinned
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    Pill { Layout.fillWidth: true; label: modelData.title || modelData.app_id || "window"; onClicked: Wm.focusWindow(modelData.id) }
                    Pill { label: "Unpin"; onClicked: Uwm.togglePin(modelData) }
                }
            }
            Pill {
                visible: Uwm.focusedWindow !== null
                label: Uwm.focusedWindow && Uwm.focusedWindow.pinned ? "Unpin focused window" : "Pin focused window"
                onClicked: Uwm.togglePin(Uwm.focusedWindow)
            }

            // saved viewpoints: click to go there, + saves the current one in the next free slot
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: Uwm.bookmarks
                    delegate: Pill {
                        required property var modelData
                        label: String(modelData.n)
                        onClicked: Uwm.gotoBookmark(modelData.n)
                    }
                }
                Pill {
                    label: "+ Save view"
                    onClicked: {
                        const used = Uwm.bookmarks.map(b => b.n)
                        let n = 1
                        while (used.includes(n)) n++
                        Uwm.saveBookmark(n)
                    }
                }
            }
        }
    }
}
