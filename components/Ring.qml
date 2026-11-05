import QtQuick
import qs.config

// Activity-style progress ring: faint track, rounded-cap arc from 12 o'clock, centred label.
// `value` is 0..100 and eases to new values.
Item {
    id: r
    property real value: 0
    property color color: Theme.primary
    property real thickness: 8
    property string text: ""
    property int textSize: 17

    readonly property color track: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
    property real shown: Math.max(0, Math.min(100, value))
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    onShownChanged: cv.requestPaint()
    onColorChanged: cv.requestPaint()
    onTrackChanged: cv.requestPaint()
    onThicknessChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const cx = width / 2, cy = height / 2
            const rad = Math.min(width, height) / 2 - r.thickness / 2
            if (rad <= 0) return
            const a0 = -Math.PI / 2

            ctx.lineWidth = r.thickness
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.arc(cx, cy, rad, 0, Math.PI * 2)
            ctx.strokeStyle = Qt.rgba(r.track.r, r.track.g, r.track.b, r.track.a)
            ctx.stroke()

            if (r.shown > 0.4) {
                ctx.beginPath()
                ctx.arc(cx, cy, rad, a0, a0 + Math.PI * 2 * r.shown / 100)
                ctx.strokeStyle = Qt.rgba(r.color.r, r.color.g, r.color.b, 1)
                ctx.stroke()
            }
        }
    }

    Txt {
        anchors.centerIn: parent
        text: r.text
        font.pixelSize: r.textSize
        font.weight: Font.Bold
    }
}
