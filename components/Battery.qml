import QtQuick
import Quickshell.Services.UPower
import qs.config

// Drawn battery: outlined shell, rounded level fill, terminal nub, bolt while charging.
// Fill turns red when low and accent-coloured while charging. `size` is the rough icon size
// (same scale as Icon.size), so it can replace an <Icon> one-to-one.
Item {
    id: b

    property int size: 17
    property bool showPercent: false

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev !== undefined && dev.isPresent
    readonly property real level: present ? Math.max(0, Math.min(1, dev.percentage)) : 0
    readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
    readonly property bool low: present && !charging && level <= 0.15
    readonly property color tint: charging ? Theme.primary : (low ? Theme.error : Theme.fg)

    readonly property real bodyH: Math.round(size * 0.74)
    readonly property real bodyW: Math.round(size * 1.45)
    readonly property real nubW: Math.max(2, Math.round(size * 0.11))
    readonly property real stroke: size >= 16 ? 1.5 : 1.25
    readonly property real inset: stroke + 1.5

    implicitWidth: bodyW + nubW + 1 + (showPercent ? pct.implicitWidth + 6 : 0)
    implicitHeight: Math.max(bodyH, showPercent ? pct.implicitHeight : 0)

    // shell
    Rectangle {
        id: shell
        y: (b.implicitHeight - height) / 2
        width: b.bodyW; height: b.bodyH
        radius: height * 0.34
        color: "transparent"
        border.width: b.stroke
        border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.38)

        // level fill
        Rectangle {
            readonly property real innerW: shell.width - b.inset * 2
            x: b.inset; y: b.inset
            height: shell.height - b.inset * 2
            width: b.level > 0 ? Math.max(height * 0.7, innerW * b.level) : 0
            radius: Math.max(1, shell.radius - b.inset + 0.5)
            color: b.tint
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // bolt
        Icon {
            anchors.centerIn: parent
            visible: b.charging
            name: "bolt"
            size: Math.round(b.bodyH * 0.95)
            filled: true
            weight: 600
            color: b.level > 0.55 ? Theme.bg : b.tint
        }
    }

    // terminal nub
    Rectangle {
        x: b.bodyW + 1
        y: shell.y + (shell.height - height) / 2
        width: b.nubW; height: Math.round(b.bodyH * 0.42)
        radius: width / 2
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.38)
    }

    Txt {
        id: pct
        visible: b.showPercent
        x: b.bodyW + b.nubW + 7
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(b.level * 100) + "%"
        font.pixelSize: Math.round(b.size * 0.72)
        font.weight: Font.DemiBold
    }
}
