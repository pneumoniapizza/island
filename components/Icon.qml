import QtQuick
import qs.config

// Material Symbols ligature icon (needs "Material Symbols Rounded", Qt >= 6.7 for the axes).
// Outlined is the crisp default; `filled` fills the glyph (looks blobby on detailed icons,
// so use it for simple shapes: play, pause, battery ...). `weight` is the wght axis (100-700).
Text {
    property string name: ""
    property int size: 20
    property bool filled: false
    property int weight: 450

    text: name
    color: Theme.fg
    font.family: Theme.iconFont
    font.pixelSize: size
    // opsz follows the pixel size so strokes stay even from 16 px to 40 px
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": weight, "GRAD": 0, "opsz": Math.max(20, Math.min(48, size)) })
    // FreeType rasterisation fills overlapping glyph contours correctly; the distance-field
    // renderer left filled icons (pause, skip) hollow / with stray inner lines.
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
