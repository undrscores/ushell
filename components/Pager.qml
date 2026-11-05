import QtQuick
import "../config"

// Horizontal pages you can swipe or flip between. Put page items inside it
// (each should be `width: pager.width`). `index` is owned by the caller; the
// pager reports swipes through swiped(). With `fitHeight` the caller can bind
// its height to currentPageHeight to follow the current page's implicitHeight.
Flickable {
    id: root
    property int index: 0
    property int count: 1
    signal swiped(int index)
    default property alias pages: row.data
    readonly property real currentPageHeight: {
        const kids = row.children
        const page = kids[Math.max(0, Math.min(index, kids.length - 1))]
        return page ? page.implicitHeight : 0
    }

    clip: true
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: row.width
    contentHeight: height

    // follow the selected page; animate unless the user is dragging
    contentX: index * width
    Behavior on contentX {
        enabled: !root.dragging && !root.flicking
        Spring { preset: "glide"; epsilon: 0.4 }
    }
    onFlickStarted: cancelFlick()
    onDragEnded: {
        const frac = contentX / width - index
        let t = index
        if (frac > 0.2) t++
        else if (frac < -0.2) t--
        root.swiped(Math.max(0, Math.min(count - 1, t)))
        contentX = Qt.binding(() => root.index * root.width)
    }

    Row { id: row }
}
