pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colors hot-reload from ~/.config/quickshell/colors.json (matugen output).
// The defaults below (Material 3 baseline dark) are used until that file exists.
Singleton {
    id: root

    // light palette = matugen is in light mode (surface is light). Auto-detected, no setting.
    readonly property bool light: Qt.color(ad.surface).hslLightness > 0.5

    // island body: solid black in dark mode, the matugen surface in light mode
    readonly property color bg: light ? surface : "#000000"
    readonly property color bgClear: Qt.rgba(bg.r, bg.g, bg.b, 0)   // for fades (avoids a grey fringe)

    readonly property color surface: ad.surface
    readonly property color surfaceHi: ad.surfaceHi
    readonly property color surfaceHiest: ad.surfaceHiest
    readonly property color fg: ad.fg
    readonly property color fgDim: ad.fgDim
    readonly property color primary: ad.primary
    readonly property color primaryFg: ad.primaryFg
    readonly property color secondaryContainer: ad.secondaryContainer
    readonly property color error: ad.error
    readonly property color outline: ad.outline

    // control-center cards: neutral container with a wash of the primary accent,
    // so they visibly follow matugen (plain surface_container_* is almost grey)
    readonly property color card: Qt.tint(surfaceHi, Qt.rgba(primary.r, primary.g, primary.b, 0.16))
    readonly property color cardHi: Qt.tint(surfaceHiest, Qt.rgba(primary.r, primary.g, primary.b, 0.26))

    // extra accents: the matugen primary with its hue rotated, so multi-colour widgets
    // (e.g. the system monitor) stay in the wallpaper's palette instead of using fixed colours
    function hueShift(c, d) {
        const h = c.hslHue < 0 ? 0 : c.hslHue
        return Qt.hsla(((h + d) % 1 + 1) % 1, c.hslSaturation, c.hslLightness, 1)
    }
    readonly property color tint2: hueShift(primary, 0.11)
    readonly property color tint3: hueShift(primary, 0.22)
    readonly property color tint4: hueShift(primary, -0.11)

    readonly property string font: Config.font
    readonly property string iconFont: Config.iconFont

    // matugen rewrites the file in place; wait a beat so we never read it half written
    Timer { id: reloadTimer; interval: 80; onTriggered: colorsFile.reload() }

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reloadTimer.restart()
        onLoadFailed: reloadTimer.restart()
        adapter: JsonAdapter {
            id: ad
            property string surface: "#141218"
            property string surfaceHi: "#2b2930"
            property string surfaceHiest: "#36343b"
            property string fg: "#e6e0e9"
            property string fgDim: "#cac4d0"
            property string primary: "#d0bcff"
            property string primaryFg: "#381e72"
            property string secondaryContainer: "#4a4458"
            property string error: "#f2b8b5"
            property string outline: "#49454f"
        }
    }
}
