import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Dropdown under the top pill (click the media chip).
Overlay {
    id: root
    name: "media"

    // nothing left to show -> dismiss instead of leaving an empty card
    Connections {
        target: Media
        function onAvailableChanged() { if (!Media.available && root.open) Shell.close() }
    }

    DropCard {
        id: card
        open: root.open
        padding: 8
        contentWidth: 344
        contentHeight: player.implicitHeight

        MediaPlayer { id: player; x: card.padding; y: card.padding; width: card.contentWidth }
    }
}
