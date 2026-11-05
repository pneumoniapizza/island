import QtQuick
import qs.config

// Slim slider: icon on the left, thin track, small value on the right. No card, no pill.
// The track thickens and shows a knob while hovered / dragged. Wheel nudges by 5%.
// With iconAction a tap on the icon emits iconClicked (e.g. mute).
Item {
    id: s

    property real value: 0
    property string icon: ""
    property bool dimmed: false
    property bool iconAction: false
    readonly property bool hovered: ma.containsMouse
    signal moved(real v)
    signal iconClicked()

    implicitHeight: 28

    readonly property real iconW: 34
    readonly property real valW: 34
    readonly property real target: Math.max(0, Math.min(1, ma.pressed && !ma.tap ? ma.v : value))
    property real shown: target
    Behavior on shown { enabled: !ma.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    readonly property bool active: ma.containsMouse || ma.pressed
    readonly property color fillColor: dimmed ? Theme.fgDim : (Config.sliderAccent ? Theme.primary : Theme.fg)

    Icon {
        x: 0
        width: s.iconW - 8
        anchors.verticalCenter: parent.verticalCenter
        name: s.icon
        size: 20
        filled: false
        color: s.dimmed ? Theme.fgDim : Theme.fg
        scale: ma.pressed && ma.tap ? 0.88 : 1.0
        Behavior on scale { SpringAnimation { spring: 8; damping: 0.5; epsilon: 0.002 } }
    }

    Rectangle {
        id: track
        x: s.iconW
        width: s.width - s.iconW - s.valW
        height: s.active ? 8 : 6
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)
        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
            width: Math.max(parent.height, parent.width * s.shown)
            height: parent.height
            radius: height / 2
            color: s.fillColor
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, parent.width * s.shown - width / 2))
            color: s.fillColor
            opacity: s.active ? 1 : 0
            scale: s.active ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
    }

    Txt {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(s.shown * 100)
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Theme.fgDim
        horizontalAlignment: Text.AlignRight
    }

    MouseArea {
        id: ma
        property real v: 0
        property real px: 0
        property bool tap: false
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function val(x) { return Math.max(0, Math.min(1, (x - s.iconW) / Math.max(1, track.width))) }

        onPressed: m => {
            px = m.x
            if (m.x < s.iconW) { tap = true; v = s.value; return }
            tap = false
            v = val(m.x)
            s.moved(v)
        }
        onPositionChanged: m => {
            if (!pressed) return
            if (tap && Math.abs(m.x - px) > 3) tap = false
            if (!tap) { v = val(m.x); s.moved(v) }
        }
        onReleased: {
            if (tap && s.iconAction) s.iconClicked()
            tap = false
        }
        onWheel: w => s.moved(Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
