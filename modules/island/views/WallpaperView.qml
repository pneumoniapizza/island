import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components

// Wallpaper switcher: endless strip + matugen colour panel.
View {
    id: view
    required property var island

    // ---- geometry (derived from settings) ----
    readonly property int wallW: Config.wallpaperWidth
    readonly property int wallCardW: Math.max(80, Config.wallpaperCardWidth)
    readonly property int wallCardH: Math.round(wallCardW / 1.6)
    readonly property int wallGap: 14
    readonly property int wallStep: wallCardW + wallGap
    readonly property int wallVisible: Math.max(1, Math.floor((wallW - 32 + wallGap) / wallStep))
    readonly property int wallBodyH: Math.max(wallCardH + 8, 124)          // strip / colour panel area
    readonly property int wallsH: 64 + wallBodyH + 10 + 22 + 26
    readonly property int wantW: wallW
    readonly property int wantH: wallsH

    // ---- strip state: wallPos is a position in the (virtual, looping) strip, wallSel the real image index ----
    property int wallPos: 0
    property bool wallTune: false      // matugen colour panel open
    readonly property int wallCycles: 400
    readonly property int wallCount: Wallpapers.files.length
    readonly property bool wallLoop: Config.wallpaperLoop && wallCount > wallVisible
    readonly property int wallSel: wallCount > 0 ? ((wallPos % wallCount) + wallCount) % wallCount : 0

    // called when the switcher opens
    function shown() {
        Wallpapers.refresh()
        wallTune = false
        Qt.callLater(() => {
            wallKeys.forceActiveFocus()
            view.initWalls()
        })
    }
    Connections {
        target: Wallpapers
        function onFilesChanged() { if (island.mode === "walls") view.initWalls() }
    }
    active: island.mode === "walls"
    dims: island.sizes.walls

    // key sink: the whole page is driven from here
    Item {
        id: wallKeys
        focus: island.mode === "walls"
        Keys.onPressed: e => view.key(e)
    }

    // ---- header ----
    Item {
        x: 0; y: 14
        width: parent.width
        height: 40

        Column {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Txt { text: "Wallpapers"; font.pixelSize: 17; font.weight: Font.DemiBold; font.letterSpacing: -0.2 }
            Txt {
                text: Wallpapers.status
                font.pixelSize: 11
                color: Wallpapers.error !== "" ? Theme.error : Theme.fgDim
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // dark / light
            Rectangle {
                width: 72; height: 34; radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surfaceHi
                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: [{ m: "dark", i: "dark_mode" }, { m: "light", i: "light_mode" }]
                        Rectangle {
                            id: seg
                            required property var modelData
                            width: 33; height: 30; radius: 15
                            color: Wallpapers.mode === seg.modelData.m ? Theme.primary : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Icon {
                                anchors.centerIn: parent
                                name: seg.modelData.i
                                size: 17
                                filled: true
                                color: Wallpapers.mode === seg.modelData.m ? Theme.primaryFg : Theme.fgDim
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpapers.setMode(seg.modelData.m)
                            }
                        }
                    }
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 36; implicitHeight: 36
                name: "palette"; size: 20; filled: view.wallTune
                fill: view.wallTune ? Theme.primary : "transparent"
                color: view.wallTune ? Theme.primaryFg : Theme.fg
                onClicked: view.wallTune = !view.wallTune
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 36; implicitHeight: 36
                name: "shuffle"; size: 20; filled: false
                onClicked: { Wallpapers.random(); view.selectWall(Wallpapers.index) }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 36; implicitHeight: 36
                name: "close"; size: 20; filled: false
                onClicked: island.closeIsland()
            }
        }
    }

    // ---- the strip: a virtual, endless list so wrapping never shows a seam ----
    ListView {
        id: wallList
        x: 0
        y: 64 + (view.wallBodyH - height) / 2
        width: parent.width
        height: view.wallCardH + 8
        orientation: ListView.Horizontal
        spacing: 0
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        model: view.wallLoop ? view.wallCount * view.wallCycles : view.wallCount

        opacity: view.wallTune ? 0 : 1
        visible: opacity > 0.01
        enabled: !view.wallTune
        Behavior on opacity { NumberAnimation { duration: 180 } }

        property bool animate: true
        readonly property real maxX: Math.max(0, count * view.wallStep - view.wallGap - width)

        Behavior on contentX {
            enabled: wallList.animate
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        function scrollTo(x) { contentX = Math.max(0, Math.min(maxX, x)) }
        function center(i) { scrollTo(i * view.wallStep + view.wallCardW / 2 - width / 2) }

        WheelHandler {
            onWheel: e => {
                const d = e.angleDelta.x !== 0 ? e.angleDelta.x : e.angleDelta.y
                view.moveWall(d < 0 ? 1 : -1)
            }
        }

        delegate: Item {
            id: card
            required property int index
            readonly property string path: Wallpapers.files.length > 0 ? (Wallpapers.files[index % Wallpapers.files.length] ?? "") : ""
            readonly property bool cur: path !== "" && path === Wallpapers.current
            readonly property bool sel: index === view.wallPos
            readonly property real dist: Math.min(1, Math.abs(index - view.wallPos))

            width: view.wallStep
            height: wallList.height

            ClippingRectangle {
                id: thumb
                y: 4
                width: view.wallCardW
                height: view.wallCardH
                radius: 24
                color: Theme.surfaceHi
                scale: cma.pressed ? 0.96 : 1.0 - 0.07 * card.dist
                opacity: 1.0 - 0.25 * card.dist
                Behavior on scale { SpringAnimation { spring: 8; damping: 0.55; epsilon: 0.002 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Image {
                    anchors.fill: parent
                    source: card.path !== "" ? "file://" + card.path : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    sourceSize.width: view.wallCardW * 2
                    sourceSize.height: view.wallCardH * 2
                    scale: card.sel ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    visible: card.cur
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    width: 26; height: 26; radius: 13
                    color: Theme.primary
                    Icon { anchors.centerIn: parent; name: "check"; size: 17; color: Theme.primaryFg }
                }
            }

            // selection ring
            Rectangle {
                y: thumb.y
                width: thumb.width
                height: thumb.height
                radius: thumb.radius
                scale: thumb.scale
                color: "transparent"
                border.width: card.sel ? 3 : 0
                border.color: Theme.primary
            }

            MouseArea {
                id: cma
                y: thumb.y
                width: thumb.width
                height: thumb.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: view.wallPos = card.index
                onClicked: { view.wallPos = card.index; view.wallCenter(true); Wallpapers.apply(card.path) }
            }
        }
    }

    // edge fades
    Rectangle {
        x: 0; y: wallList.y
        width: 36; height: wallList.height
        visible: wallList.visible && (view.wallLoop || wallList.contentX > 4)
        opacity: wallList.opacity
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.bg }
            GradientStop { position: 1.0; color: Theme.bgClear }
        }
    }
    Rectangle {
        x: parent.width - 36; y: wallList.y
        width: 36; height: wallList.height
        visible: wallList.visible && (view.wallLoop || wallList.contentX < wallList.maxX - 4)
        opacity: wallList.opacity
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.bgClear }
            GradientStop { position: 1.0; color: Theme.bg }
        }
    }

    // ---- matugen panel (palette button / t) ----
    Item {
        x: 0; y: 64
        width: parent.width
        height: view.wallBodyH
        opacity: view.wallTune ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 14

            // scheme
            Item {
                width: parent.width
                height: Math.max(28, schemeFlow.implicitHeight)
                Txt { width: 76; height: 28; text: "Scheme"; font.pixelSize: 12; color: Theme.fgDim }
                Flow {
                    id: schemeFlow
                    x: 76
                    width: parent.width - 76
                    spacing: 6
                    Repeater {
                        model: Wallpapers.schemes
                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool on: Wallpapers.schemeId === chip.modelData.id
                            width: chipTxt.implicitWidth + 24
                            height: 28
                            radius: 14
                            color: chip.on ? Theme.primary : (chipMa.containsMouse ? Theme.surfaceHiest : Theme.surfaceHi)
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Txt {
                                id: chipTxt
                                anchors.centerIn: parent
                                text: chip.modelData.name
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: chip.on ? Theme.primaryFg : Theme.fgDim
                            }
                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpapers.setScheme(chip.modelData.id)
                            }
                        }
                    }
                }
            }

            // contrast
            Item {
                width: parent.width
                height: 28
                Txt { width: 76; height: 28; text: "Contrast"; font.pixelSize: 12; color: Theme.fgDim }
                Item {
                    id: cBox
                    x: 76
                    width: parent.width - 76 - 52
                    height: 28
                    readonly property real p: (Wallpapers.contrast + 1) / 2

                    Item {
                        id: ct
                        x: 10
                        width: parent.width - 20
                        height: parent.height
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 6; radius: 3
                            color: Theme.surfaceHiest
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.min(cBox.p, 0.5) * parent.width
                            width: Math.abs(cBox.p - 0.5) * parent.width
                            height: 6; radius: 3
                            color: Theme.primary
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width / 2 - 1
                            width: 2; height: 14; radius: 1
                            color: Theme.outline
                            z: -1
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: cBox.p * parent.width - 10
                            width: 20; height: 20; radius: 10
                            color: Theme.fg
                            scale: cMa.pressed ? 1.12 : 1.0
                            Behavior on scale { SpringAnimation { spring: 8; damping: 0.5; epsilon: 0.002 } }
                        }
                    }
                    MouseArea {
                        id: cMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function set(x) { Wallpapers.setContrast(Math.max(0, Math.min(1, (x - 10) / ct.width)) * 2 - 1) }
                        onPressed: m => set(m.x)
                        onPositionChanged: m => { if (pressed) set(m.x) }
                        onDoubleClicked: Wallpapers.setContrast(0)
                    }
                }
                Txt {
                    x: parent.width - 48
                    width: 48; height: 28
                    horizontalAlignment: Text.AlignRight
                    text: Wallpapers.contrastLabel
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            // accent
            Item {
                width: parent.width
                height: 28
                Txt { width: 76; height: 28; text: "Accent"; font.pixelSize: 12; color: Theme.fgDim }
                Row {
                    x: 76
                    spacing: 8
                    Rectangle {
                        width: autoRow.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: Wallpapers.accent === "" ? Theme.primary : (autoMa.containsMouse ? Theme.surfaceHiest : Theme.surfaceHi)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Row {
                            id: autoRow
                            anchors.centerIn: parent
                            spacing: 5
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "image"; size: 15; filled: true; color: Wallpapers.accent === "" ? Theme.primaryFg : Theme.fgDim }
                            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Wallpaper"; font.pixelSize: 12; font.weight: Font.Medium; color: Wallpapers.accent === "" ? Theme.primaryFg : Theme.fgDim }
                        }
                        MouseArea {
                            id: autoMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.setAccent("")
                        }
                    }
                    Repeater {
                        model: Config.accentPresets
                        Rectangle {
                            id: sw
                            required property string modelData
                            readonly property bool on: Wallpapers.accent.toLowerCase() === sw.modelData.toLowerCase()
                            width: 28; height: 28; radius: 14
                            color: sw.modelData
                            scale: swMa.pressed ? 0.9 : (swMa.containsMouse ? 1.1 : 1.0)
                            Behavior on scale { SpringAnimation { spring: 8; damping: 0.5; epsilon: 0.002 } }
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: sw.on ? 3 : 0
                                border.color: Theme.fg
                            }
                            MouseArea {
                                id: swMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpapers.setAccent(sw.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- footer ----
    RowLayout {
        x: 0; y: 64 + view.wallBodyH + 10
        width: parent.width
        height: 22
        spacing: 16
        Txt {
            Layout.fillWidth: true
            text: view.wallTune
                  ? Wallpapers.schemeLabel + "  ·  contrast " + Wallpapers.contrastLabel + "  ·  " + (Wallpapers.accent === "" ? "from wallpaper" : Wallpapers.accent)
                  : (Wallpapers.files.length > 0 ? (view.wallSel + 1) + "/" + Wallpapers.files.length + "  ·  " + Wallpapers.baseName(Wallpapers.files[view.wallSel] ?? "") : "")
            font.pixelSize: 11
            color: Theme.fgDim
        }

        // key hints: a small keycap + a dim label each
        Row {
            id: hintRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 12

            readonly property var hints: view.wallTune
                ? [["s", "scheme"], ["c", "contrast"], ["a", "accent"], ["m", "mode"], ["x", "reset"], ["t", "back"]]
                : (Config.vimKeys
                    ? [["h l", "move"], ["⏎", "apply"], ["t", "colors"], ["r", "random"], ["esc", "close"]]
                    : [["← →", "move"], ["⏎", "apply"], ["t", "colors"], ["esc", "close"]])
            readonly property string pending: (island.vimCount > 0 ? island.vimCount : "") + island.vimPending

            // vim count / pending key, shown as a highlighted cap while you type it
            Rectangle {
                visible: hintRow.pending !== ""
                height: 20; width: Math.max(20, pendTxt.implicitWidth + 12); radius: 7
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                Txt { id: pendTxt; anchors.centerIn: parent; text: hintRow.pending; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.primaryFg }
            }

            Repeater {
                model: hintRow.hints
                delegate: Row {
                    required property var modelData
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20; width: Math.max(20, capTxt.implicitWidth + 12); radius: 7
                        color: Theme.card
                        Txt { id: capTxt; anchors.centerIn: parent; text: modelData[0]; font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.fg }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        font.pixelSize: 11
                        color: Theme.fgDim
                        opacity: 0.85
                    }
                }
            }
        }
    }

    // empty state
    Column {
        visible: Wallpapers.files.length === 0 && !view.wallTune
        anchors.horizontalCenter: parent.horizontalCenter
        y: 84
        spacing: 8
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "wallpaper"; size: 32; color: Theme.fgDim }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "No images in " + Wallpapers.dir; font.pixelSize: 12; color: Theme.fgDim }
    }

    // ---- wallpaper strip ----
    // In loop mode the strip is a virtual list of wallCount * wallCycles cards and wallPos is a
    // position inside it, so moving past either end just keeps scrolling: no jump, no seam.
    function wallCenter(animate) {
        wallList.animate = animate
        wallList.center(wallPos)
        wallList.animate = true
    }
    function initWalls() {
        const n = wallCount
        if (n === 0) { wallPos = 0; return }
        wallPos = (wallLoop ? n * Math.floor(wallCycles / 2) : 0) + Math.max(0, Wallpapers.index)
        Qt.callLater(() => wallCenter(false))
    }
    function moveWall(d) {
        const n = wallCount
        if (n === 0) return
        if (!wallLoop) {
            wallPos = Math.max(0, Math.min(n - 1, wallPos + d))
        } else {
            wallPos += d
            // far from the middle: silently shift by whole cycles (looks identical)
            const lo = n * Math.floor(wallCycles / 4), hi = n * Math.floor(wallCycles * 3 / 4)
            if (wallPos < lo || wallPos > hi) {
                const shift = Math.round((n * Math.floor(wallCycles / 2) - wallPos) / n) * n
                wallPos += shift
                wallList.animate = false
                wallList.contentX += shift * wallStep
                wallList.animate = true
            }
        }
        wallCenter(true)
    }
    // jump to a real index by the shortest way round
    function selectWall(i) {
        const n = wallCount
        if (n === 0) return
        i = Math.max(0, Math.min(n - 1, i))
        let d = i - wallSel
        if (wallLoop) { if (d > n / 2) d -= n; else if (d < -n / 2) d += n }
        moveWall(d)
    }
    function wallApply() {
        const f = Wallpapers.files[wallSel]
        if (f) Wallpapers.apply(f)
    }

    // matugen panel helpers
    function cycleScheme(d) {
        const l = Wallpapers.schemes
        const i = l.findIndex(s => s.id === Wallpapers.schemeId)
        Wallpapers.setScheme(l[(i + d + l.length) % l.length].id)
    }
    function cycleAccent(d) {
        const l = [""].concat(Config.accentPresets)
        const i = Math.max(0, l.findIndex(c => c.toLowerCase() === Wallpapers.accent.toLowerCase()))
        Wallpapers.setAccent(l[(i + d + l.length) % l.length])
    }

    function key(e) {
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
        const k = e.key
        const t = e.text
        const vim = Config.vimKeys
        const n = Math.max(1, island.vimCount)
        const last = Wallpapers.files.length - 1
        e.accepted = true

        if (ctrl && (k === Qt.Key_C || k === Qt.Key_BracketLeft)) { island.closeIsland(); return }

        // ---- colour panel ----
        if (wallTune) {
            if (k === Qt.Key_Escape || k === Qt.Key_Return || k === Qt.Key_Enter || t === "t") { wallTune = false; return }
            switch (t) {
            case "s": cycleScheme(1); break
            case "S": cycleScheme(-1); break
            case "c": case "+": case "=": Wallpapers.setContrast(Wallpapers.contrast + 0.1); break
            case "C": case "-": Wallpapers.setContrast(Wallpapers.contrast - 0.1); break
            case "a": cycleAccent(1); break
            case "A": cycleAccent(-1); break
            case "m": Wallpapers.setMode(Wallpapers.mode === "dark" ? "light" : "dark"); break
            case "x": Wallpapers.resetStyle(); break
            case "q": island.closeIsland(); break
            }
            if (k === Qt.Key_Right) Wallpapers.setContrast(Wallpapers.contrast + 0.1)
            else if (k === Qt.Key_Left) Wallpapers.setContrast(Wallpapers.contrast - 0.1)
            return
        }

        if (k === Qt.Key_Escape) { island.closeIsland(); return }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { wallApply(); island.vimReset(); return }
        if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) { moveWall(-n); island.vimReset(); return }
        if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) { moveWall(n); island.vimReset(); return }
        if (k === Qt.Key_Home)     { selectWall(0); island.vimReset(); return }
        if (k === Qt.Key_End)      { selectWall(last); island.vimReset(); return }
        if (k === Qt.Key_PageDown) { moveWall(wallVisible); island.vimReset(); return }
        if (k === Qt.Key_PageUp)   { moveWall(-wallVisible); island.vimReset(); return }
        if (k === Qt.Key_Backspace) { island.page = "center"; return }

        if (ctrl) {
            if (!vim) return
            const half = Math.ceil(wallVisible / 2)
            if (k === Qt.Key_D) moveWall(half * n)
            else if (k === Qt.Key_U) moveWall(-half * n)
            else if (k === Qt.Key_F) moveWall(wallVisible * n)
            else if (k === Qt.Key_B) moveWall(-wallVisible * n)
            else if (k === Qt.Key_N) moveWall(n)
            else if (k === Qt.Key_P) moveWall(-n)
            island.vimReset()
            return
        }
        if (t === "t") { wallTune = true; island.vimReset(); return }
        if (!vim || t === "") return

        if (t >= "0" && t <= "9" && !(t === "0" && island.vimCount === 0)) { island.vimCount = island.vimCount * 10 + parseInt(t); return }

        const pend = island.vimPending
        island.vimPending = ""
        switch (t) {
        case "h": case "k": moveWall(-n); break
        case "l": case "j": moveWall(n); break
        case "w": moveWall(wallVisible * n); break
        case "b": moveWall(-wallVisible * n); break
        case "g":
            if (pend === "g") selectWall(Math.min(last, island.vimCount > 0 ? island.vimCount - 1 : 0))
            else { island.vimPending = "g"; return }
            break
        case "G": selectWall(Math.min(last, island.vimCount > 0 ? island.vimCount - 1 : last)); break
        case "0": selectWall(0); break
        case "$": selectWall(last); break
        case "o": case "a": wallApply(); break
        case "r": Wallpapers.random(); selectWall(Wallpapers.index); break
        case "n": Wallpapers.next(); selectWall(Wallpapers.index); break
        case "N": Wallpapers.prev(); selectWall(Wallpapers.index); break
        case "m": Wallpapers.setMode(Wallpapers.mode === "dark" ? "light" : "dark"); break
        case "q": island.closeIsland(); break
        }
        island.vimCount = 0
    }
}
