import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Right auto-hiding widgets panel. Mod+A pins it open.
Variants {
    model: Quickshell.screens

    EdgePanel {
        id: win
        required property var modelData
        screen: modelData
        edge: "right"
        pinned: Shell.widgetsPinned
        panelWidth: 340
        panelHeight: Math.min(modelData.height - 2 * Theme.margin - 80, 700)
        onShownChanged: Shell.widgetsShown = shown

        SystemClock { id: clock; precision: SystemClock.Minutes }

        ColumnLayout {
            x: 20; y: 20
            width: parent.width - 40
            spacing: 20

            Column {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 40; weight: Font.Light }
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Theme.fgDim
                    font { family: Theme.font; pixelSize: Theme.fontSize + 1 }
                }
            }

            MediaCard { Layout.fillWidth: true }
            Calendar  { Layout.fillWidth: true }
            StatBars  { Layout.fillWidth: true }
        }
    }
}
