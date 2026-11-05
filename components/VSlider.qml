import QtQuick
import Quickshell.Widgets
import qs.config

// Tall pill slider: fills from the bottom, icon sits at the base, percentage on top.
// With iconAction a tap on the icon area (no drag) emits iconClicked (e.g. mute).
// Mouse wheel nudges the value by 5%.
Item {
    id: s

    property real value: 0
    property string icon: ""
    property bool dimmed: false
    property bool iconAction: false
    readonly property bool hovered: ma.containsMouse
    signal moved(real v)
    signal iconClicked()

    readonly property real target: Math.max(0, Math.min(1, ma.pressed ? ma.v : value))
    property real shown: target
    Behavior on shown { enabled: !ma.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    readonly property bool accented: Config.sliderAccent && !dimmed
    readonly property color fillColor: dimmed ? Theme.fgDim : (Config.sliderAccent ? Theme.primary : Theme.fg)
    readonly property color onFill: accented ? Theme.primaryFg : Theme.surface
    readonly property bool iconCovered: shown * height > 46
    readonly property bool pctCovered: shown * height > height - 38

    ClippingRectangle {
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, ma.containsMouse ? 0.13 : 0.08)
        Behavior on color { ColorAnimation { duration: 140 } }

        // fill: rounded cap on top, the bottom is clipped away by the card
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -28
            width: parent.width
            height: s.shown * s.height + 28
            radius: 28
            color: s.fillColor
            visible: s.shown > 0.004
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        text: Math.round(s.shown * 100)
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: s.pctCovered ? s.onFill : Theme.fgDim
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        name: s.icon
        size: 24
        filled: true
        color: s.iconCovered ? s.onFill : Theme.fg
        scale: ma.pressed && ma.tap ? 0.88 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { SpringAnimation { spring: 8; damping: 0.5; epsilon: 0.002 } }
    }

    MouseArea {
        id: ma
        property real v: 0
        property real py: 0
        property bool tap: false
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function val(y) { return Math.max(0, Math.min(1, 1 - y / s.height)) }

        onPressed: m => {
            py = m.y
            tap = s.iconAction && m.y > s.height - 60
            if (tap) {
                v = s.value
            } else {
                v = val(m.y)
                s.moved(v)
            }
        }
        onPositionChanged: m => {
            if (!pressed) return
            if (tap && Math.abs(m.y - py) > 3) tap = false
            if (!tap) {
                v = val(m.y)
                s.moved(v)
            }
        }
        onReleased: {
            if (tap) s.iconClicked()
            tap = false
        }
        onWheel: w => s.moved(Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
