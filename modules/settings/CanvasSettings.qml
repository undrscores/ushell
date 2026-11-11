import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

// Canvas: the shell's uwc-specific pieces (minimap, edge markers, zoomed-out labels, hot corners, frosted panels).
ColumnLayout {
    spacing: 22

    SettingsGroup {
        title: "Canvas"
        SettingRow {
            icon: ""; title: "Edge markers"; hint: "A dot and arrow on the screen edge for each window outside the view"
            Switch { checked: Prefs.offscreenPips; onToggled: v => Prefs.set("offscreenPips", v) }
        }
        SettingRow {
            icon: ""; title: "Labels when zoomed out"; hint: "Icon and title over each window once you zoom far out"
            Switch { checked: Prefs.overviewLabels; onToggled: v => Prefs.set("overviewLabels", v) }
        }
        SettingRow {
            icon: ""; title: "Zoomed out below"; hint: "Where the labels start to fade in"
            Row {
                spacing: 4
                Repeater {
                    model: [0.3, 0.5, 0.7]
                    delegate: Pill { required property real modelData; label: Math.round(modelData * 100) + "%"; active: Math.abs(Prefs.overviewZoom - modelData) < 0.005
                                     onClicked: Prefs.set("overviewZoom", modelData) }
                }
            }
        }
        SettingRow {
            icon: ""; title: "Hide the bar when zoomed out"; hint: "The top pill folds away below that zoom, even when it is set to stay visible"
            Switch { checked: Prefs.zoomAutoHide; onToggled: v => Prefs.set("zoomAutoHide", v) }
        }
    }

    SettingsGroup {
        title: "Compositor"
        SettingRow {
            icon: ""; title: "Window colours follow the theme"; hint: "uwc's focus border, glow and snap guides take the accent and wallpaper colours"
            Switch { checked: Prefs.compositorColors; onToggled: v => Prefs.set("compositorColors", v) }
        }
    }

    SettingsGroup {
        title: "Hot corners"
        SettingRow {
            icon: ""; title: "Hot corners"; hint: "Rest the pointer in a screen corner to run its action. A few pixels of each corner stop taking clicks."
            Switch { checked: Prefs.hotCorners; onToggled: v => Prefs.set("hotCorners", v) }
        }
        Repeater {
            model: [ { key: "hotCornerTL", label: "Top left" }, { key: "hotCornerTR", label: "Top right" },
                     { key: "hotCornerBL", label: "Bottom left" }, { key: "hotCornerBR", label: "Bottom right" } ]
            delegate: SettingRow {
                id: corner
                required property var modelData
                visible: Prefs.hotCorners
                title: modelData.label
                Flow {
                    width: 400
                    spacing: 4
                    Repeater {
                        model: [ { l: "Off", a: "" }, { l: "Overview", a: "uwc:overview" }, { l: "Home", a: "uwc:home" },
                                 { l: "Map", a: "shell:minimap" }, { l: "Launcher", a: "shell:launcher" }, { l: "Alerts", a: "shell:notifications" } ]
                        delegate: Pill { required property var modelData; label: modelData.l; active: Prefs[corner.modelData.key].replace(/^uwm:/, "uwc:") === modelData.a
                                         onClicked: Prefs.set(corner.modelData.key, modelData.a) }
                    }
                }
            }
        }
        SettingRow {
            visible: Prefs.hotCorners
            icon: ""; title: "Rest time"; hint: "How long the pointer has to stay in the corner"
            Row {
                spacing: 4
                Repeater {
                    model: [200, 350, 500, 800]
                    delegate: Pill { required property int modelData; label: modelData + " ms"; active: Prefs.hotCornerDwell === modelData
                                     onClicked: Prefs.set("hotCornerDwell", modelData) }
                }
            }
        }
    }

    SettingsGroup {
        title: "Panels"
        SettingRow {
            icon: ""; title: "Frosted panels"; hint: "Blur what is behind panels. Only visible when glassOpacity in config.json is below 1."
            Switch { checked: Prefs.frostedPanels; onToggled: v => Prefs.set("frostedPanels", v) }
        }
    }
}
