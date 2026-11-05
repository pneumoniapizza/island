import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components

// Compact pill while something plays: cover art left (shared Art item),
// clock (pill.clockWithMedia), live timer / privacy dot and battery icon in the middle,
// equalizer right.
View {
    id: view
    required property var island
    active: island.mode === "media"
    dims: island.sizes.media

    Row {
        anchors.centerIn: parent
        spacing: 7
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.pillClockWithMedia
            text: Qt.formatDateTime(Clock.date, Config.timeFormat)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.4
        }
        Row {
            visible: Countdown.active
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "timer"
                size: 14
                filled: Countdown.running
                color: Countdown.running ? Theme.primary : Theme.fgDim
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Countdown.formatted
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Countdown.running ? Theme.primary : Theme.fgDim
            }
        }
        Battery {
            anchors.verticalCenter: parent.verticalCenter
            visible: island.pillBattery
            size: 17
        }
        Rectangle {
            visible: Privacy.active
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: Privacy.color
            Behavior on color { ColorAnimation { duration: 180 } }

            SequentialAnimation on opacity {
                running: Privacy.active && view.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 850; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: 850; easing.type: Easing.InOutSine }
            }
        }
    }

    Equalizer {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        running: island.mediaPlaying
    }
}
