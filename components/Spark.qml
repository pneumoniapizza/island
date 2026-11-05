import QtQuick
import qs.config

// Smooth gradient area graph of the latest samples, newest on the right, with a glowing end dot.
// `values` are 0..1. The vertical range auto-scales (never below 25%) so quiet periods
// still show shape instead of a flat line on the floor.
Canvas {
    id: c
    property var values: []
    property int slots: 60
    property color stroke: Theme.primary
    readonly property color grid: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.07)

    onValuesChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onGridChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0) return

        const padT = 10, padB = 6, padR = 8
        const plotH = height - padT - padB

        // faint guides: top, middle and floor
        ctx.lineWidth = 1
        ctx.strokeStyle = Qt.rgba(grid.r, grid.g, grid.b, grid.a)
        for (let k = 0; k < 3; k++) {
            const gy = Math.round(padT + plotH * k / 2) + 0.5
            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
        }

        const n = values.length
        if (n < 1) return

        let peak = 0
        for (let i = 0; i < n; i++) peak = Math.max(peak, values[i])
        const top = Math.min(1, Math.max(0.25, peak * 1.25))

        const step = (width - padR) / (slots - 1)
        const px = i => (width - padR) - (n - 1 - i) * step
        const py = v => padT + plotH * (1 - Math.max(0, Math.min(1, v / top)))

        if (n >= 2) {
            const trace = () => {
                ctx.moveTo(px(0), py(values[0]))
                for (let i = 1; i < n; i++) {
                    const mx = (px(i - 1) + px(i)) / 2
                    const my = (py(values[i - 1]) + py(values[i])) / 2
                    ctx.quadraticCurveTo(px(i - 1), py(values[i - 1]), mx, my)
                }
                ctx.lineTo(px(n - 1), py(values[n - 1]))
            }

            const g = ctx.createLinearGradient(0, padT, 0, height)
            g.addColorStop(0, Qt.rgba(stroke.r, stroke.g, stroke.b, 0.38))
            g.addColorStop(1, Qt.rgba(stroke.r, stroke.g, stroke.b, 0.0))
            ctx.beginPath()
            trace()
            ctx.lineTo(px(n - 1), height - padB)
            ctx.lineTo(px(0), height - padB)
            ctx.closePath()
            ctx.fillStyle = g
            ctx.fill()

            ctx.beginPath()
            trace()
            ctx.strokeStyle = Qt.rgba(stroke.r, stroke.g, stroke.b, 1)
            ctx.lineWidth = 2.5
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.stroke()
        }

        // end dot with a soft halo
        const ex = px(n - 1), ey = py(values[n - 1])
        ctx.beginPath(); ctx.arc(ex, ey, 7, 0, Math.PI * 2)
        ctx.fillStyle = Qt.rgba(stroke.r, stroke.g, stroke.b, 0.22); ctx.fill()
        ctx.beginPath(); ctx.arc(ex, ey, 3.5, 0, Math.PI * 2)
        ctx.fillStyle = Qt.rgba(stroke.r, stroke.g, stroke.b, 1); ctx.fill()
    }
}
