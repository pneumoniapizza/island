import QtQuick
import qs.config

// Control-center tile: flat rounded square, icon top-left, label + state bottom-left.
// Fills with the accent when active; otherwise a faint neutral wash (no coloured card).
Item {
    id: t

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool more: false          // small chevron (top-right) that opens a picker
    signal clicked()
    signal moreClicked()

    readonly property color onColor: t.active ? Theme.primaryFg : Theme.fg
    readonly property color onDim: t.active ? Qt.rgba(Theme.primaryFg.r, Theme.primaryFg.g, Theme.primaryFg.b, 0.72) : Theme.fgDim

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 26
        opacity: t.available ? 1 : 0.4
        color: t.active ? Theme.primary
                        : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, ma.containsMouse ? 0.13 : 0.08)
        scale: ma.pressed ? 0.97 : 1.0
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { SpringAnimation { spring: 8; damping: 0.5; epsilon: 0.002 } }

        Icon {
            x: 16; y: 16
            name: t.icon
            size: 28
            filled: false
            weight: 500
            color: t.onColor
        }

        Column {
            x: 16
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
            width: parent.width - 28
            spacing: 0
            Txt { width: parent.width; text: t.label; font.pixelSize: 14; font.weight: Font.DemiBold; color: t.onColor }
            Txt { width: parent.width; visible: text !== ""; text: t.subtitle; font.pixelSize: 11; color: t.onDim }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: t.available
        cursorShape: Qt.PointingHandCursor
        onClicked: t.clicked()
    }

    // chevron
    Item {
        visible: t.more
        anchors.top: parent.top; anchors.right: parent.right
        width: 38; height: 38
        Icon {
            anchors.centerIn: parent
            name: "chevron_right"
            size: 18
            color: moreMa.containsMouse ? t.onColor : t.onDim
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        MouseArea {
            id: moreMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: t.available
            cursorShape: Qt.PointingHandCursor
            onClicked: t.moreClicked()
        }
    }
}
