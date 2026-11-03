import QtQuick
import Quickshell.Widgets
import qs.config

// Rounded cover art / notification image with icon fallback.
// ClippingRectangle clips with a smooth (antialiased) rounded edge; the old MultiEffect
// mask rendered jagged, stair-stepped corners when the art was scaled down.
ClippingRectangle {
    id: root

    property url source
    property string fallback: "music_note"

    color: img.status === Image.Ready ? "transparent" : Theme.surfaceHi

    Icon {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        name: root.fallback
        size: Math.round(root.height * 0.55)
        color: Theme.fgDim
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize.width: 192
        sourceSize.height: 192
    }
}
