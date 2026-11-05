import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components

// Hover state with a full player.
View {
    id: view
    required property var island
    active: island.mode === "player"
    dims: island.sizes.player
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 10
        spacing: 4

        // media on the left, clock on the right
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            spacing: 14
            Item { Layout.preferredWidth: 72; Layout.preferredHeight: 72 }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3
                Marquee { Layout.fillWidth: true; text: island.title; pixelSize: 16 }
                Txt { Layout.fillWidth: true; text: island.artist; font.pixelSize: 13; color: Theme.fgDim }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                spacing: 0
                Txt {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDateTime(Clock.date, Config.timeFormat)
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.5
                }
                Row {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(Clock.date, Config.shortDateFormat)
                        font.pixelSize: 11
                        color: Theme.fgDim
                    }
                    Battery {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: island.pillBattery
                        size: 15
                    }
                }
            }
        }

        // ---- scrub bar ----
        Item {
            id: seek
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            Layout.topMargin: 8
            readonly property bool hot: sma.containsMouse || island.scrubbing

            Rectangle {
                id: rail
                width: parent.width
                height: seek.hot ? 8 : 5
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: Theme.secondaryContainer
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: Theme.fg
                    width: Math.max(height, rail.width * island.shownRatio)
                    // glide between 250ms position polls; follow the cursor 1:1 while dragging
                    Behavior on width {
                        enabled: !island.scrubbing && !island.holdSeek
                        NumberAnimation { duration: 260; easing.type: Easing.Linear }
                    }
                }
            }

            MouseArea {
                id: sma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: island.hasMedia && island.player.canSeek
                onPressed: m => { island.scrubRatio = Math.max(0, Math.min(1, m.x / width)); island.scrubbing = true }
                onPositionChanged: m => { if (pressed) island.scrubRatio = Math.max(0, Math.min(1, m.x / width)) }
                onReleased: island.commitSeek()
                onCanceled: island.scrubbing = false
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 12
            Txt {
                text: island.fmt(island.shownRatio * island.trackLen)
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Theme.fgDim
            }
            Item { Layout.fillWidth: true }
            Txt {
                text: "-" + island.fmt(island.trackLen * (1 - island.shownRatio))
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Theme.fgDim
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.topMargin: 2

            Equalizer {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                running: island.mediaPlaying
            }

            Row {
                anchors.centerIn: parent
                spacing: 38
                IconButton {
                    name: "skip_previous"
                    size: 26
                    hoverFill: false
                    enabled: island.hasMedia && island.player.canGoPrevious
                    opacity: enabled ? 1 : 0.35
                    onClicked: island.player.previous()
                }
                IconButton {
                    name: island.mediaPlaying ? "pause" : "play_arrow"
                    size: 34
                    hoverFill: false
                    implicitWidth: 52
                    onClicked: island.player.togglePlaying()
                }
                IconButton {
                    name: "skip_next"
                    size: 26
                    hoverFill: false
                    enabled: island.hasMedia && island.player.canGoNext
                    opacity: enabled ? 1 : 0.35
                    onClicked: island.player.next()
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 32
                implicitHeight: 32
                name: "tune"
                size: 18
                filled: false
                onClicked: island.page = "center"
            }
        }
    }
}
