import QtQuick
import Quickshell.Io
import qs.config

// One notification in the control center: app icon, title, body (tap to expand), the app's own
// action buttons, swipe sideways to dismiss, hover for copy / close.
// Use as a ListView delegate (needs the `modelData` entry from Notifs.history).
Item {
    id: it

    required property var modelData
    readonly property var entry: modelData
    property double now: Date.now()
    property bool expanded: false
    signal dismissed()
    signal invoked(string actionId)

    readonly property string cleanBody: (entry.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
    readonly property var buttons: {
        const a = entry.actions || []
        if (a.length > 0) return a.slice(0, 3)
        return entry.hasDefault ? [{ id: "default", text: "Open" }] : []
    }
    readonly property color accent: entry.critical ? Theme.error : Theme.fgDim

    function relTime(t) {
        const s = Math.max(0, Math.round((it.now - t) / 1000))
        if (s < 45) return "now"
        const m = Math.round(s / 60)
        if (m < 60) return m + "m"
        const h = Math.round(m / 60)
        if (h < 24) return h + "h"
        return Qt.formatDateTime(new Date(t), "d MMM")
    }

    height: card.height + 8

    Process { id: copier; command: ["wl-copy", "--", it.cleanBody] }
    Timer { id: leaveTimer; interval: 190; onTriggered: it.dismissed() }

    Rectangle {
        id: card
        width: it.width
        height: head.height + (btnRow.visible ? btnRow.height + 10 : 0) + 24
        radius: 20
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, hover.hovered ? 0.11 : 0.07)
        border.width: it.entry.critical ? 1 : 0
        border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.55)
        opacity: 1 - Math.min(0.75, Math.abs(x) / (width * 0.6))

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on x { enabled: !drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        HoverHandler { id: hover }

        // tap: expand a long body, otherwise run the click action
        MouseArea {
            anchors.fill: parent
            cursorShape: bodyTxt.truncated || it.expanded || it.entry.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (bodyTxt.truncated || it.expanded) it.expanded = !it.expanded
                else if (it.entry.hasDefault) it.invoked("default")
            }
        }

        // swipe either way to dismiss
        DragHandler {
            id: drag
            target: card
            yAxis.enabled: false
            xAxis.minimum: -it.width
            xAxis.maximum: it.width
            onActiveChanged: {
                if (active) return
                if (Math.abs(card.x) > it.width * 0.33) {
                    card.x = (card.x < 0 ? -1 : 1) * it.width
                    leaveTimer.start()
                } else card.x = 0
            }
        }

        Item {
            id: head
            x: 12; y: 12
            width: card.width - 24
            height: Math.max(art.height, textCol.implicitHeight)

            Art {
                id: art
                width: 38; height: 38
                radius: 12
                source: it.entry.image
                fallback: "notifications"
            }

            Column {
                id: textCol
                x: 48
                width: parent.width - 48
                spacing: 1

                Item {
                    width: parent.width; height: 14
                    Txt {
                        anchors.left: parent.left
                        width: parent.width - 52
                        text: it.entry.app
                        font.pixelSize: 10
                        font.letterSpacing: 0.9
                        font.capitalization: Font.AllUppercase
                        color: it.accent
                    }
                    Txt {
                        anchors.right: parent.right
                        text: it.relTime(it.entry.time)
                        font.pixelSize: 10
                        color: Theme.fgDim
                        opacity: hover.hovered ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
                Txt {
                    width: parent.width
                    visible: text !== ""
                    text: it.entry.title
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Txt {
                    id: bodyTxt
                    width: parent.width
                    visible: text !== ""
                    text: it.cleanBody
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: it.expanded ? 12 : 2
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: Theme.fgDim
                }
            }

            // hover tools (replace the time stamp)
            Row {
                anchors.right: parent.right
                y: -5
                spacing: 2
                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 120 } }
                IconButton {
                    implicitWidth: 24; implicitHeight: 24
                    name: "content_copy"; size: 14; filled: false
                    onClicked: copier.running = true
                }
                IconButton {
                    implicitWidth: 24; implicitHeight: 24
                    name: "close"; size: 15; filled: false
                    onClicked: it.dismissed()
                }
            }
        }

        // the app's own actions
        Row {
            id: btnRow
            x: 12; y: head.y + head.height + 10
            visible: it.buttons.length > 0
            height: 30
            spacing: 8
            Repeater {
                model: it.buttons
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool primary: index === 0
                    height: 30
                    width: Math.min(130, lbl.implicitWidth + 28)
                    radius: 11
                    color: primary ? Theme.primary
                                   : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, bma.containsMouse ? 0.20 : 0.11)
                    scale: bma.pressed ? 0.95 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.5; epsilon: 0.002 } }
                    Txt {
                        id: lbl
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, btn.width - 20)
                        text: btn.modelData.text
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: btn.primary ? Theme.primaryFg : Theme.fg
                    }
                    MouseArea {
                        id: bma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: it.invoked(btn.modelData.id)
                    }
                }
            }
        }
    }
}
