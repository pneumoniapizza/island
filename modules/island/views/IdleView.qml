import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components

// Idle pill: time, optional battery icon, live countdown timer, and iOS-style privacy dot.
View {
    id: view
    required property var island
    active: island.mode === "idle"
    dims: island.sizes.idle

    Row {
        anchors.centerIn: parent
        spacing: 7

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(Clock.date, Config.timeFormat)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.4
        }

        // live countdown badge
        Row {
            visible: Countdown.active
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "timer"
                size: 15
                filled: Countdown.running
                color: Countdown.running ? Theme.primary : Theme.fgDim
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Countdown.formatted
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Countdown.running ? Theme.primary : Theme.fgDim
            }
        }

        Battery {
            anchors.verticalCenter: parent.verticalCenter
            visible: island.pillBattery
            size: 17
        }

        // minimal iOS-style privacy dot (orange = mic, green = camera, red = screen record)
        Item {
            visible: Privacy.active || dotScale.running
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8

            Rectangle {
                id: privDot
                anchors.centerIn: parent
                width: 7; height: 7; radius: 3.5
                color: Privacy.color
                scale: Privacy.active ? 1.0 : 0.0
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on scale {
                    SpringAnimation { id: dotScale; spring: 6.5; damping: 0.48; epsilon: 0.005 }
                }

                SequentialAnimation on opacity {
                    running: Privacy.active && view.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.45; duration: 850; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 850; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
