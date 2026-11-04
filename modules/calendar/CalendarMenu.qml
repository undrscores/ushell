import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Dropdown under the top pill (click the clock).
Overlay {
    id: root
    name: "calendar"
    onOpenChanged: if (open) cal.reset()

    DropCard {
        id: card
        open: root.open
        contentWidth: 290
        contentHeight: cal.implicitHeight

        Calendar { id: cal; x: card.padding; y: card.padding; width: card.contentWidth }
    }
}
