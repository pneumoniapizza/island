import QtQuick
import QtQuick.Layouts
import qs.config

// Card with a coloured label, a progress ring and a one-line detail underneath.
Card {
    id: t
    property string icon: ""
    property string label: ""
    property real pct: 0
    property string detail: ""
    property color tint: Theme.primary
    property color warn: Theme.error
    readonly property color tone: pct >= 90 ? warn : tint

    Layout.fillWidth: true
    Layout.fillHeight: true

    Row {
        x: 16; y: 15
        spacing: 5
        Icon { name: t.icon; size: 15; filled: true; color: t.tone; anchors.verticalCenter: parent.verticalCenter }
        Txt { text: t.label; font.pixelSize: 12; font.weight: Font.DemiBold; color: t.tone; anchors.verticalCenter: parent.verticalCenter }
    }

    Ring {
        width: 74; height: 74
        x: (t.width - width) / 2; y: 40
        value: t.pct
        color: t.tone
        thickness: 8
        text: Math.round(t.pct) + "%"
        textSize: 16
    }

    Txt {
        x: 8; y: t.height - 30
        width: t.width - 16
        horizontalAlignment: Text.AlignHCenter
        text: t.detail
        font.pixelSize: 11
        color: Theme.fgDim
    }
}
