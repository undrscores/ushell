import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Item {
    id: page
    implicitHeight: Weather.ok ? col.implicitHeight : 190
    readonly property var now: Weather.describe(Weather.code, Weather.isDay)

    function dayName(iso, i) {
        if (i === 0) return "Today"
        return Qt.formatDate(new Date(iso + "T12:00:00"), "ddd")
    }

    // loading / error state
    Item {
        anchors.fill: parent
        visible: !Weather.ok
        Column {
            anchors.centerIn: parent
            spacing: 10
            Icon {
                id: spin
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.error !== "" ? "" : ""
                size: 30; color: Theme.fgDim
                RotationAnimation on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: Weather.loading && page.visible }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.error !== "" ? Weather.error : "Fetching weather…"
                   color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
            IconButton { visible: Weather.error !== ""; anchors.horizontalCenter: parent.horizontalCenter; icon: ""; onClicked: Weather.refresh() }
        }
    }

    ColumnLayout {
        id: col
        visible: Weather.ok
        width: parent.width
        spacing: 16

        // place + refresh
        RowLayout {
            Layout.fillWidth: true
            Icon { text: ""; size: 13; color: Theme.accent }
            Text { Layout.fillWidth: true; text: Weather.place; elide: Text.ElideRight; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize } }
            IconButton {
                size: 28; icon: ""; onClicked: Weather.refresh()
                rotation: 0
                RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: Weather.loading && page.visible }
            }
        }

        // current conditions
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Icon { text: page.now.icon; size: 56; color: Theme.accent; Layout.alignment: Qt.AlignVCenter }
            ColumnLayout {
                spacing: 0
                Text { text: Math.round(Weather.temp) + Weather.tempUnit; color: Theme.fg; font { family: Theme.font; pixelSize: 44; weight: Font.Light } }
                Text { text: page.now.text; color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize + 2 } }
                Text { text: "Feels like " + Math.round(Weather.feels) + "°"; color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 } }
            }
        }

        // details
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    { icon: "", text: Weather.humidity + "%" },
                    { icon: "", text: Math.round(Weather.wind) + " " + Weather.windUnit }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.radiusSmall + 2
                    color: Theme.tint
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { text: modelData.icon; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.text; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter; font { family: Theme.font; pixelSize: Theme.fontSize } }
                    }
                }
            }
        }

        // forecast
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 110
            radius: Theme.radius
            color: Theme.tint
            Row {
                anchors.fill: parent
                anchors.margins: 8
                Repeater {
                    model: Weather.daily
                    delegate: Item {
                        id: day
                        required property var modelData
                        required property int index
                        width: parent.width / Math.max(1, Weather.daily.length)
                        height: parent.height
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: page.dayName(day.modelData.date, day.index)
                                   color: day.index === 0 ? Theme.accent : Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.describe(day.modelData.code, true).icon; size: 22; color: Theme.fg }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(day.modelData.max) + "°"
                                   color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize - 1; bold: true } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(day.modelData.min) + "°"
                                   color: Theme.fgDim; font { family: Theme.font; pixelSize: Theme.fontSize - 2 } }
                        }
                    }
                }
            }
        }
    }
}
