import Quickshell
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../../config"
import "../../services"
import "../../components"
import "../../config/palette.js" as Palette
import "../../services/wall.js" as Wall

// Wallpaper picker (launcher: "Wallpapers", or `qs ipc call shell toggle wallpapers`): a row of slanted slices,
// the focused one wide and the rest tapering away. Type to search, Tab to switch between all / favourites / a folder,
// ← → to browse, Enter to apply, Ctrl+F to star, Ctrl+T for dark / light. The theme strip on top sets the accent.
Overlay {
    id: root
    name: "wallpapers"
    scrim: 0.55

    // ── what is shown ──────────────────────────────────────────────────────
    property string query: ""
    property string filter: "all"                 // all | favs | folder:<name>
    readonly property var list: Wall.filterList(Wallpapers.files, query, filter, Prefs.wallpaperFavs, Wallpapers.dir)
    readonly property int n: list.length
    readonly property var filters: [{ id: "all", label: "All" }, { id: "favs", label: "★ Favourites" }]
        .concat(Wallpapers.folders.map(f => ({ id: "folder:" + f, label: f })))

    // focused slice; `pos` follows it with a spring so the row glides
    property int cur: 0
    property real pos: 0
    property bool glide: false
    property string lastPath: ""
    Behavior on pos { enabled: root.glide; Spring { preset: "glide"; epsilon: 0.003 } }
    onCurChanged: { pos = cur; lastPath = list[cur] ?? "" }
    onListChanged: {                              // keep the focused picture if it is still there, else the current wallpaper, else the first
        let i = lastPath !== "" ? list.indexOf(lastPath) : -1
        if (i < 0) i = list.indexOf(Wallpapers.current)
        cur = Math.max(0, i)
        pos = cur
    }
    function step(d) { if (n > 0) cur = Math.max(0, Math.min(n - 1, cur + d)) }
    function apply() { if (list[cur]) Wallpapers.set(list[cur]) }
    function applyHere() { if (list[cur]) Wallpapers.setFor(Wm.focusedOutput, list[cur]) }       // only the screen you are on
    function cycleFilter() {
        const i = filters.findIndex(f => f.id === filter)
        filter = filters[(i + 1) % filters.length].id
    }

    onOpenChanged: if (open) {
        glide = false
        query = ""; filter = "all"
        lastPath = Wallpapers.current
        Wallpapers.refresh()
        const i = list.indexOf(Wallpapers.current)
        cur = Math.max(0, i); pos = cur
        input.text = ""
        Qt.callLater(() => { glide = true; input.forceActiveFocus() })
    }

    // ── layout ─────────────────────────────────────────────────────────────
    Item {
        id: stage
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
        transform: Translate { y: root.open ? 0 : 18; Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easing } } }

        // theme strip: dark / light and the accent colour
        Rectangle {
            id: strip
            anchors.horizontalCenter: parent.horizontalCenter
            y: 36
            width: stripRow.implicitWidth + 28; height: 44
            radius: height / 2
            color: Theme.glass
            border { width: 1; color: Theme.line }
            Row {
                id: stripRow
                anchors.centerIn: parent
                spacing: 12
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Pill { label: "Dark";  active: Prefs.themeMode === "dark";  onClicked: Prefs.set("themeMode", "dark") }
                    Pill { label: "Light"; active: Prefs.themeMode === "light"; onClicked: Prefs.set("themeMode", "light") }
                }
                Rectangle { width: 1; height: 20; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Repeater {
                        model: Palette.names
                        delegate: Rectangle {
                            id: sw
                            required property string modelData
                            readonly property bool chosen: !Prefs.wallpaperColors && Palette.make(Theme.mode, Prefs.accent).accentName === modelData
                            width: 22; height: 22; radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: Palette.make(Theme.mode, modelData).accent
                            border { width: chosen ? 2 : 0; color: Theme.fg }
                            opacity: Wallpapers.useColors ? 0.45 : 1
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                            scale: swMa.pressed ? 0.85 : (swMa.containsMouse ? 1.18 : (chosen ? 1.08 : 1))
                            Behavior on scale { Pop {} }
                            MouseArea {
                                id: swMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Prefs.set("accent", sw.modelData); Prefs.set("wallpaperColors", false) }
                            }
                        }
                    }
                    Rectangle {          // the colours of the current wallpaper
                        id: wsw
                        readonly property bool usable: Prefs.wallpaper !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 11
                        color: Wallpapers.colorsOk ? Palette.make(Theme.mode, "mauve", { hue: Wallpapers.hue, sat: Wallpapers.sat, hue2: Wallpapers.hue2 >= 0 ? Wallpapers.hue2 : undefined, sat2: Wallpapers.sat2 }).accent : Theme.surfaceHi
                        Behavior on color { ColorAnimation { duration: Theme.animFade } }
                        border { width: Prefs.wallpaperColors ? 2 : 1; color: Prefs.wallpaperColors ? Theme.fg : Theme.line }
                        opacity: usable ? 1 : 0.35
                        scale: wMa.pressed ? 0.85 : (wMa.containsMouse && usable ? 1.18 : (Prefs.wallpaperColors ? 1.08 : 1))
                        Behavior on scale { Pop {} }
                        Icon { anchors.centerIn: parent; text: ""; size: 10; color: Wallpapers.colorsOk ? Theme.accentFg : Theme.fgDim }
                        MouseArea {
                            id: wMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: wsw.usable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Prefs.set("wallpaperColors", !Prefs.wallpaperColors)
                        }
                    }
                }
            }
        }

        // the slices
        Item {
            id: carousel
            anchors { left: parent.left; right: parent.right }
            height: sliceH
            y: Math.max(strip.y + strip.height + 24, (parent.height - height) / 2 - 20)
            clip: false

            readonly property real sliceH: Math.max(220, Math.min(380, root.height - 330))
            readonly property real skew: sliceH * 0.15
            readonly property real cw: 84                          // a slice that is not focused
            readonly property real ew: Math.min(580, width * 0.34)  // the focused one
            readonly property real gapX: 10
            readonly property int span: Math.ceil(width / (cw + gapX) / 2) + 2
            readonly property int lo: Math.max(0, Math.floor(root.pos) - span)
            readonly property int hi: Math.min(root.n - 1, Math.floor(root.pos) + 1 + span)
            function wOf(d) { return cw + (ew - cw) * Math.max(0, 1 - Math.abs(d)) }

            // horizontal centre of each slice from lo to hi. The point `pos` along the row sits in the middle of the screen.
            readonly property var xs: {
                const out = []
                if (hi < lo) return out
                const p = root.pos, b = Math.floor(p), f = p - b
                const stepOf = k => (wOf(k - p) + wOf(k + 1 - p)) / 2 + gapX      // centre of k to centre of k + 1
                const c = {}
                c[b] = -f * stepOf(b)
                for (let i = b + 1; i <= hi; i++) c[i] = c[i - 1] + stepOf(i - 1)
                for (let i = b - 1; i >= lo; i--) c[i] = c[i + 1] - stepOf(i)
                for (let i = lo; i <= hi; i++) out.push(width / 2 + c[i])
                return out
            }
            // the slice under a point (slices are parallelograms, so their bounding boxes overlap)
            function sliceAt(mx, my) {
                if (my < 0 || my > sliceH) return -1
                let best = -1, bestD = 1e9
                for (let i = lo; i <= hi; i++) {
                    const w = wOf(i - root.pos), x0 = xs[i - lo] - (w + skew) / 2
                    const l = x0 + skew * (1 - my / sliceH)
                    if (mx >= l && mx <= l + w) { const dd = Math.abs(i - root.pos); if (dd < bestD) { best = i; bestD = dd } }
                }
                return best
            }

            Repeater {
                model: root.n
                delegate: Item {
                    id: sl
                    required property int index
                    readonly property bool near: index >= carousel.lo && index <= carousel.hi
                    readonly property real d: index - root.pos
                    readonly property real w: carousel.wOf(d)
                    readonly property real t: Math.max(0, 1 - Math.abs(d))      // 1 = focused
                    readonly property string path: root.list[index] ?? ""
                    readonly property bool applied: path !== "" && path === Wallpapers.current
                    visible: near
                    width: w + carousel.skew; height: carousel.sliceH
                    x: near ? (carousel.xs[index - carousel.lo] ?? 0) - width / 2 : 0
                    z: 10 - Math.abs(d)

                    Loader {
                        anchors.fill: parent
                        active: sl.near
                        sourceComponent: Item {
                            Item {
                                id: mask
                                anchors.fill: parent
                                visible: false
                                layer.enabled: true
                                layer.samples: 4
                                Shape {
                                    anchors.fill: parent
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        fillColor: "white"; strokeColor: "transparent"
                                        startX: carousel.skew; startY: 0
                                        PathLine { x: sl.width; y: 0 }
                                        PathLine { x: sl.width - carousel.skew; y: sl.height }
                                        PathLine { x: 0; y: sl.height }
                                        PathLine { x: carousel.skew; y: 0 }
                                    }
                                }
                            }
                            Image {
                                id: img
                                anchors.fill: parent
                                visible: false
                                source: Wallpapers.url(sl.path)
                                sourceSize: Qt.size(720, 440)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            MultiEffect {
                                anchors.fill: parent
                                source: img
                                maskEnabled: true; maskSource: mask
                                brightness: -0.3 * (1 - sl.t)
                                saturation: -0.45 * (1 - sl.t)
                                opacity: img.status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
                            }
                            Shape {          // outline round the wallpaper that is in use
                                anchors.fill: parent
                                visible: sl.applied
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    fillColor: "transparent"; strokeColor: Theme.accent; strokeWidth: 3
                                    joinStyle: ShapePath.MiterJoin
                                    startX: carousel.skew + 1.5; startY: 1.5
                                    PathLine { x: sl.width - 1.5; y: 1.5 }
                                    PathLine { x: sl.width - carousel.skew - 1.5; y: sl.height - 1.5 }
                                    PathLine { x: 1.5; y: sl.height - 1.5 }
                                    PathLine { x: carousel.skew + 1.5; y: 1.5 }
                                }
                            }
                            Icon {           // starred
                                visible: Wallpapers.isFav(sl.path)
                                x: sl.width - carousel.skew - 22; y: 10
                                text: ""; size: 13; color: Theme.accent
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: carousel.sliceAt(mouseX, mouseY) >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: m => {
                    const i = carousel.sliceAt(m.x, m.y)
                    if (i < 0) Shell.close()
                    else if (i === root.cur) root.apply()
                    else root.cur = i
                }
                onWheel: w => root.step((Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) ? w.angleDelta.x : w.angleDelta.y) > 0 ? -1 : 1)
            }
        }

        // name of the focused picture
        Row {
            id: info
            anchors.horizontalCenter: parent.horizontalCenter
            y: carousel.y + carousel.height + 22
            spacing: 12
            visible: root.n > 0
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Wallpapers.nameOf(root.list[root.cur] ?? "")
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize + 3; bold: true }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: Wallpapers.folderOf(root.list[root.cur] ?? "")
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.cur + 1) + " / " + root.n
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
            Pill {
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool fav: Wallpapers.isFav(root.list[root.cur] ?? "")
                label: fav ? "★ Starred" : "☆ Star"
                active: fav
                onClicked: Wallpapers.toggleFav(root.list[root.cur])
            }
            Pill { visible: Quickshell.screens.length > 1; anchors.verticalCenter: parent.verticalCenter; label: "This screen"; onClicked: root.applyHere() }
            Pill { anchors.verticalCenter: parent.verticalCenter; label: "Apply"; active: true; onClicked: root.apply() }
        }

        // nothing to show
        Column {
            anchors.centerIn: carousel
            visible: root.n === 0
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !Wallpapers.scanned ? "Looking for pictures…" : (Wallpapers.files.length === 0 ? "No pictures found" : (root.filter === "favs" && root.query === "" ? "Nothing starred yet" : "No wallpapers match"))
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize + 2 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Wallpapers.scanned && Wallpapers.files.length === 0
                text: "Put images in " + Wallpapers.dir.replace(Wallpapers.home, "~") + ",\nor set \"wallpaperDir\" in config.json"
                horizontalAlignment: Text.AlignHCenter
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
        }

        // search and filters
        Rectangle {
            id: bar
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 56
            width: Math.min(parent.width - 48, barRow.implicitWidth + 28); height: 48
            radius: height / 2
            color: Theme.glass
            border { width: 1; color: Theme.line }
            Row {
                id: barRow
                anchors.centerIn: parent
                spacing: 12
                Rectangle {
                    width: 220; height: 32; radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.tint
                    border { width: 1; color: input.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent" }
                    Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; text: ""; size: 12; color: Theme.fgDim }
                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 32; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        selectionColor: Theme.accent; selectedTextColor: Theme.accentFg
                        font { family: Theme.font; pixelSize: Theme.fontSize }
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier
                            if (e.key === Qt.Key_Escape) { if (text !== "") text = ""; else Shell.close() }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (e.modifiers & Qt.ShiftModifier) root.applyHere(); else root.apply() }
                            else if (e.key === Qt.Key_Left)  root.step(-1)
                            else if (e.key === Qt.Key_Right) root.step(1)
                            else if (e.key === Qt.Key_Home)  root.cur = 0
                            else if (e.key === Qt.Key_End)   root.cur = Math.max(0, root.n - 1)
                            else if (e.key === Qt.Key_Tab)   root.cycleFilter()
                            else if (ctrl && e.key === Qt.Key_F) Wallpapers.toggleFav(root.list[root.cur])
                            else if (ctrl && e.key === Qt.Key_R) Wallpapers.random()
                            else if (ctrl && e.key === Qt.Key_T) Prefs.set("themeMode", Prefs.themeMode === "dark" ? "light" : "dark")
                            else return
                            e.accepted = true
                        }
                        Text {
                            visible: !input.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search…"
                            color: Theme.fgDim
                            font: input.font
                        }
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: root.filters
                        delegate: Pill {
                            required property var modelData
                            label: modelData.label
                            active: root.filter === modelData.id
                            onClicked: { root.filter = modelData.id; input.forceActiveFocus() }
                        }
                    }
                }
                Pill { anchors.verticalCenter: parent.verticalCenter; label: "Random"; onClicked: Wallpapers.random() }
                Pill { anchors.verticalCenter: parent.verticalCenter; label: "Off"; visible: Prefs.wallpaper !== ""; onClicked: Wallpapers.off() }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: bar.y + bar.height + 12
            text: "← → browse  ·  Enter apply  ·  Tab filter  ·  Ctrl+F star  ·  Ctrl+T dark / light  ·  Esc close"
            color: Theme.fgDim
            opacity: 0.8
            font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
        }
    }
}
