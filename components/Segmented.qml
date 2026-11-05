import QtQuick
import qs.config

// iOS-style segmented control: a pill with a sliding thumb.
Item {
    id: s
    property var options: []
    property int index: 0
    signal picked(int i)

    implicitWidth: 112
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
    }

    Rectangle {
        id: thumb
        y: 2
        height: s.height - 4
        width: (s.width - 4) / Math.max(1, s.options.length)
        radius: height / 2
        x: 2 + s.index * width
        color: Theme.secondaryContainer
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    Repeater {
        model: s.options
        delegate: Item {
            id: seg
            required property int index
            required property var modelData
            x: 2 + index * thumb.width
            width: thumb.width
            height: s.height

            Txt {
                anchors.centerIn: parent
                text: seg.modelData
                font.pixelSize: 12
                font.weight: s.index === seg.index ? Font.DemiBold : Font.Medium
                color: s.index === seg.index ? Theme.fg : Theme.fgDim
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: s.picked(seg.index)
            }
        }
    }
}
