import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// System monitor, wide layout: CPU graph + memory / disk / GPU rings on top,
// network + top processes underneath. All colours follow matugen (see Theme.tint2..4).
// Keys: s or Tab = switch process sort (CPU / memory), Esc / q = close.
// Nothing is polled unless this page is on screen (see Sys.watching).
View {
    id: view
    required property var island

    readonly property int procRows: Math.min(6, Math.max(0, Config.sysmonProcesses))

    // ---- palette (matugen) ----
    readonly property bool colorful: Config.sysmonColors
    readonly property color cCpu:  Theme.primary
    readonly property color cMem:  colorful ? Theme.tint2 : Theme.primary
    readonly property color cDisk: colorful ? Theme.tint3 : Theme.primary
    readonly property color cGpu:  colorful ? Theme.tint4 : Theme.primary
    readonly property color cDown: colorful ? Theme.tint2 : Theme.primary
    readonly property color cUp:   Theme.primary
    readonly property color cWarn: Theme.error
    readonly property color hairline: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)

    // ---- geometry ----
    readonly property int gap: 10
    readonly property int leftW: 310
    readonly property int topY: 46
    readonly property int topH: 150
    readonly property int botY: topY + topH + gap
    readonly property int botH: 108

    readonly property int wantW: 820
    readonly property int wantH: botY + botH + 16

    active: island.mode === "sysmon"
    dims: island.sizes.sysmon

    Binding { target: Sys; property: "watching"; value: view.active }

    function shown() { Qt.callLater(() => { if (view.active) view.forceActiveFocus() }) }
    onVisibleChanged: if (visible && active) view.forceActiveFocus()

    Keys.onPressed: e => {
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
        e.accepted = true
        if (e.key === Qt.Key_Escape || e.text === "q" || (ctrl && e.key === Qt.Key_C)) { island.closeIsland(); return }
        if (e.key === Qt.Key_Tab || e.text === "s") { Sys.setSort(!Sys.sortByMem); return }
        e.accepted = false
    }

    // ".spotify-wrappe" -> "Spotify" (nix wrappers + truncated comm names)
    function cleanName(n) {
        const s = n.replace(/^\./, "").replace(/-wr(a(p(p(e(d)?)?)?)?)?$/, "")
        return s.length ? s[0].toUpperCase() + s.slice(1) : n
    }

    // ================= header =================
    Txt {
        x: 4; y: 8; height: 30
        text: "System"
        font.pixelSize: 20
        font.weight: Font.Bold
    }
    Txt {
        anchors.right: parent.right; anchors.rightMargin: 6
        y: 8; height: 30
        visible: Sys.uptime !== ""
        text: "Up " + Sys.uptime
        font.pixelSize: 12
        color: Theme.fgDim
    }

    // ================= top row: CPU + rings =================
    RowLayout {
        x: 0; y: view.topY
        width: parent.width; height: view.topH
        spacing: view.gap

        Card {
            id: cpuCard
            Layout.preferredWidth: view.leftW
            Layout.fillWidth: false
            Layout.fillHeight: true

            readonly property color tone: Sys.cpu >= 90 ? view.cWarn : view.cCpu

            Row {
                x: 20; y: 16
                spacing: 5
                Icon { name: "memory"; size: 15; filled: true; color: cpuCard.tone; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: "CPU"; font.pixelSize: 12; font.weight: Font.DemiBold; color: cpuCard.tone; anchors.verticalCenter: parent.verticalCenter }
            }

            Txt {
                id: cpuNum
                x: 20; y: 38
                height: 58
                text: Math.round(Sys.cpu)
                font.pixelSize: 52
                font.weight: Font.Bold
            }
            Txt {
                anchors.left: cpuNum.right; anchors.leftMargin: 3
                anchors.baseline: cpuNum.baseline
                text: "%"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: Theme.fgDim
            }

            Txt {
                x: 20; y: cpuCard.height - 34
                width: 112
                readonly property var parts: {
                    const p = []
                    if (Sys.temp >= 0) p.push(Math.round(Sys.temp) + "°")
                    if (Sys.load !== "") p.push("Load " + Sys.load.split("  ")[0])
                    return p
                }
                text: parts.join("  ·  ")
                font.pixelSize: 12
                color: Theme.fgDim
            }

            Spark {
                x: 132; y: 10
                width: cpuCard.width - 132 - 12
                height: cpuCard.height - 20
                slots: Sys.histLen
                stroke: cpuCard.tone
                values: Sys.cpuHist.map(v => v / 100)
            }
        }

        RingTile {
            icon: "developer_board"; label: "Memory"
            pct: Sys.memPct
            detail: Sys.fmtPair(Sys.memUsed * 1024, Sys.memTotal * 1024)
            tint: view.cMem; warn: view.cWarn
        }
        RingTile {
            icon: "storage"; label: "Disk"
            pct: Sys.diskPct
            detail: Sys.fmtPair(Sys.diskUsed, Sys.diskTotal)
            tint: view.cDisk; warn: view.cWarn
        }
        RingTile {
            visible: Sys.gpu >= 0
            icon: "videogame_asset"; label: "GPU"
            pct: Sys.gpu
            detail: "Usage"
            tint: view.cGpu; warn: view.cWarn
        }
    }

    // ================= bottom row: network + processes =================
    RowLayout {
        x: 0; y: view.botY
        width: parent.width; height: view.botH
        spacing: view.gap

        // ---- network ----
        Card {
            id: netCard
            Layout.preferredWidth: view.leftW
            Layout.fillWidth: view.procRows === 0
            Layout.fillHeight: true

            Rectangle {   // centre divider
                x: parent.width / 2; y: 18
                width: 1; height: parent.height - 36
                color: view.hairline
            }

            Repeater {
                model: 2
                delegate: Item {
                    id: half
                    required property int index
                    readonly property bool down: index === 0
                    readonly property var parts: Sys.bytesParts(down ? Sys.rx : Sys.tx)
                    readonly property color tone: down ? view.cDown : view.cUp

                    x: index * netCard.width / 2
                    width: netCard.width / 2
                    height: netCard.height

                    Row {
                        x: 20; y: 20
                        spacing: 5
                        Icon {
                            name: half.down ? "arrow_downward" : "arrow_upward"
                            size: 16; weight: 600
                            color: half.tone
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Txt {
                            text: half.down ? "Download" : "Upload"
                            font.pixelSize: 12; font.weight: Font.DemiBold
                            color: half.tone
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        x: 20; y: 46
                        width: num.width + 3 + unit.width
                        height: num.height
                        Txt { id: num; text: half.parts.n; font.pixelSize: 26; font.weight: Font.Bold }
                        Txt {
                            id: unit
                            anchors.left: num.right; anchors.leftMargin: 3
                            anchors.baseline: num.baseline
                            text: half.parts.u + "/s"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.fgDim
                        }
                    }
                }
            }
        }

        // ---- top processes: one chip per process ----
        Card {
            id: procCard
            visible: view.procRows > 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property color tone: Sys.sortByMem ? view.cMem : view.cCpu

            Txt {
                x: 20; y: 10; height: 30
                text: "Processes"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Segmented {
                x: procCard.width - width - 14; y: 11
                width: 104; height: 26
                options: ["CPU", "MEM"]
                index: Sys.sortByMem ? 1 : 0
                onPicked: i => Sys.setSort(i === 1)
            }

            RowLayout {
                x: 20; y: 50
                width: procCard.width - 40; height: 48
                spacing: 12

                // fixed chips reading Sys.procs[index], so nothing is rebuilt on every refresh
                Repeater {
                    model: view.procRows
                    delegate: Item {
                        id: chip
                        required property int index
                        readonly property var p: Sys.procs[index]
                        readonly property real v: p ? (Sys.sortByMem ? p.mem : p.cpu) : 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        opacity: p !== undefined ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Txt {
                            y: 4; width: parent.width; height: 16
                            text: chip.p ? view.cleanName(chip.p.name) : ""
                            font.pixelSize: 12
                            color: Theme.fgDim
                        }
                        Txt {
                            y: 22; width: parent.width; height: 22
                            text: chip.p ? chip.v.toFixed(1) + "%" : ""
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: chip.index === 0 ? procCard.tone : Theme.fg
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        Rectangle {   // faint divider between columns
                            visible: chip.index < view.procRows - 1
                            x: parent.width + 6; y: 4
                            width: 1; height: parent.height - 8
                            color: view.hairline
                        }
                    }
                }
            }
        }
    }
}
