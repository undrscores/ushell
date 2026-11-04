import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Item {
    id: page
    implicitHeight: col.implicitHeight

    function gb(v) { return v.toFixed(v >= 100 ? 0 : 1) }
    function duration(sec) {
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
        return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m")
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // CPU headline + history
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 104
            radius: Theme.radius
            color: Theme.tint
            Text {
                x: 16; y: 12
                text: "CPU"
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
            Text {
                x: 16; y: 28
                text: Math.round(Stats.cpu * 100) + "%"
                color: Stats.cpu > 0.85 ? Theme.danger : Theme.fg
                font { family: Theme.font; pixelSize: 30; weight: Font.Light }
            }
            Text {
                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 14 }
                text: "load " + Stats.load.toFixed(2)
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            }
            Sparkline {
                anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 14 }
                width: parent.width - 32 - 80
                height: 44
                values: Stats.cpuHistory
            }
        }

        StatRow { Layout.fillWidth: true; icon: "󰍛"; label: "Memory"; value: Stats.mem
                  detail: page.gb(Stats.memUsed) + " / " + page.gb(Stats.memTotal) + " GB" }
        StatRow { Layout.fillWidth: true; visible: Stats.hasGpu; icon: ""; label: "GPU"; value: Stats.gpu
                  detail: Math.round(Stats.gpu * 100) + "%  ·  " + Math.round(Stats.gpuTemp) + "°C" }
        StatRow { Layout.fillWidth: true; visible: Stats.hasGpu; icon: ""; label: "VRAM"; value: Stats.vram
                  detail: page.gb(Stats.vramUsed) + " / " + page.gb(Stats.vramTotal) + " GB" }

        Repeater {
            model: Stats.disks
            delegate: StatRow {
                required property var modelData
                Layout.fillWidth: true
                icon: ""; label: modelData.label; value: modelData.frac
                detail: page.gb(modelData.used) + " / " + page.gb(modelData.size) + " GB"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Icon { text: ""; size: 13; color: Theme.fgDim }
            Text { text: "Up " + page.duration(Stats.uptime); color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
            Item { Layout.fillWidth: true }
            Text { visible: Stats.swap > 0.01; text: "swap " + Math.round(Stats.swap * 100) + "%"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
        }
    }
}
