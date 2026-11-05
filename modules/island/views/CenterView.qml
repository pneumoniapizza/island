import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.components

// Control center: connectivity tiles, sound + display sliders, notifications.
View {
    id: view
    required property var island

    // wheel over a slider / a scrollable notification list must not flip the page
    readonly property bool overSlider: sub !== "" || volSlider.hovered || briSlider.hovered || (notifList.contentHeight > notifList.height + 1 && listHover.hovered)

    // picker sub-page: "" (main) | wifi | bt
    property string sub: ""
    property string askSsid: ""                // secured network waiting for its password
    readonly property bool typing: sub === "wifi" && askSsid !== ""
    function openSub(s) {
        sub = s
        askSsid = ""
        if (s === "wifi") Controls.scanWifi()
        if (s === "bt") Controls.btScan(true)
    }
    function closeSub() {
        if (sub === "bt") Controls.btScan(false)
        sub = ""
        askSsid = ""
    }
    Connections { target: view.island; function onModeChanged() { if (view.island.mode !== "center" && view.sub !== "") view.closeSub() } }
    Connections { target: Controls; function onBtOnChanged() { if (view.sub === "bt") Controls.btScan(true) } }
    onTypingChanged: if (typing) focusTimer.restart()
    Timer { id: focusTimer; interval: 60; repeat: true
        property int n: 0
        onTriggered: { passInput.forceActiveFocus(); if (++n >= 10 || passInput.activeFocus) { stop(); n = 0 } }
    }

    function btIcon(d) {
        const i = d.icon || ""
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "headphones"
        if (i.indexOf("keyboard") >= 0) return "keyboard"
        if (i.indexOf("mouse") >= 0) return "mouse"
        if (i.indexOf("phone") >= 0) return "smartphone"
        if (i.indexOf("gaming") >= 0) return "sports_esports"
        if (i.indexOf("speaker") >= 0) return "speaker"
        return "bluetooth"
    }
    function wifiIcon(sig) { return sig > 75 ? "signal_wifi_4_bar" : sig > 50 ? "network_wifi_3_bar" : sig > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar" }
    readonly property int gap: 10

    // ticks while open so "2m" / "1h" stamps in the notification list stay fresh
    property double now: Date.now()
    Timer { interval: 30000; running: view.active; repeat: true; triggeredOnStart: true; onTriggered: view.now = Date.now() }

    // "1h 20m left" / "35m to full" / "Charging" for the header capsule
    readonly property string batStatus: {
        const d = UPower.displayDevice
        if (!d || !d.isPresent) return ""
        const fmt = sec => { const m = Math.round(sec / 60); return m >= 60 ? Math.floor(m / 60) + "h " + (m % 60) + "m" : m + "m" }
        if (d.state === UPowerDeviceState.FullyCharged) return "Charged"
        if (d.state === UPowerDeviceState.Charging) return d.timeToFull > 0 ? fmt(d.timeToFull) + " to full" : "Charging"
        return d.timeToEmpty > 0 ? fmt(d.timeToEmpty) + " left" : ""
    }
    pad: 14
    active: island.mode === "center"
    dims: island.sizes.center

    // ================= main page =================
    View {
        id: mainPage
        property var island: null   // no slide direction: same blur-fade morph as the island pages
        pad: 0
        dims: ({ w: view.width, h: view.height })
        active: view.sub === ""

        // ---- header: battery (plain) left, lock + power right ----
        Row {
            x: 2; y: 10
            height: 34
            spacing: 9
            visible: Config.showBattery && island.hasBattery
            Battery { anchors.verticalCenter: parent.verticalCenter; size: 19; showPercent: true }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: view.batStatus !== ""
                text: view.batStatus
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }
        Row {
            x: parent.width - width; y: 10
            spacing: 2
            IconButton {
                implicitWidth: 34; implicitHeight: 34
                name: "search"; size: 18; filled: false
                onClicked: island.page = "launcher"
            }
            IconButton {
                implicitWidth: 34; implicitHeight: 34
                name: "lock"; size: 18; filled: false
                onClicked: { island.closeIsland(); Power.run("lock") }
            }
            IconButton {
                implicitWidth: 34; implicitHeight: 34
                name: "power_settings_new"; size: 18; filled: false
                onClicked: island.page = "power"
            }
        }

        // ---- control grid: 2 x 2 square tiles + two tall sliders (iOS style) ----
        GridLayout {
            id: tileGrid
            x: 0; y: 54
            width: parent.width - 150 - view.gap
            height: 210
            columns: 2
            rowSpacing: view.gap
            columnSpacing: view.gap
            Tile {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 1; Layout.preferredHeight: 1
                icon: Controls.wifi ? "wifi" : "wifi_off"
                label: "Wi-Fi"
                more: true
                onMoreClicked: view.openSub("wifi")
                subtitle: !Controls.wifi ? "Off" : (Controls.wifiName !== "" ? Controls.wifiName : "On")
                active: Controls.wifi
                onClicked: Controls.toggleWifi()
            }
            Tile {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 1; Layout.preferredHeight: 1
                icon: Controls.btOn ? "bluetooth" : "bluetooth_disabled"
                label: "Bluetooth"
                more: true
                onMoreClicked: view.openSub("bt")
                subtitle: !Controls.btAvailable ? "N/A" : (!Controls.btOn ? "Off" : (Controls.btDevice !== "" ? Controls.btDevice : "On"))
                active: Controls.btOn
                available: Controls.btAvailable
                onClicked: Controls.toggleBluetooth()
            }
            Tile {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 1; Layout.preferredHeight: 1
                icon: "do_not_disturb_on"
                label: "Focus"
                subtitle: Notifs.dnd ? "On" : "Off"
                active: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Tile {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 1; Layout.preferredHeight: 1
                icon: "coffee"
                label: "Awake"
                subtitle: Controls.keepAwake ? "On" : "Off"
                active: Controls.keepAwake
                onClicked: Controls.keepAwake = !Controls.keepAwake
            }
        }

        VSlider {
            id: volSlider
            x: parent.width - 150; y: 54
            width: 70; height: 210
            icon: Controls.volumeIcon
            value: Controls.volume
            dimmed: Controls.muted
            iconAction: true
            onMoved: v => Controls.setVolume(v)
            onIconClicked: Controls.toggleMute()
        }
        VSlider {
            id: briSlider
            x: parent.width - 70; y: 54
            width: 70; height: 210
            icon: "light_mode"
            value: Controls.brightness
            onMoved: v => Controls.setBrightness(v)
        }

        // ---- notifications: one card, same wash as the tiles ----
        Rectangle {
            id: notifCard
            x: 0; y: 274
            width: parent.width
            height: view.height - 14 - y
            radius: 26
            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)

            Txt { x: 18; y: 14; text: "Notifications"; font.pixelSize: 13; font.weight: Font.DemiBold }
            Item {
                anchors.right: parent.right; anchors.rightMargin: 10
                y: 10
                visible: Notifs.history.length > 0
                width: clearTxt.implicitWidth + 16; height: 24
                Txt { id: clearTxt; anchors.centerIn: parent; text: "Clear"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.fgDim }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearHistory()
                }
            }

            Txt {
                x: 0; y: 40
                width: parent.width; height: parent.height - 40
                visible: Notifs.history.length === 0
                text: "No notifications"
                font.pixelSize: 12
                color: Theme.fgDim
                opacity: 0.7
                horizontalAlignment: Text.AlignHCenter
            }

            ListView {
                id: notifList
                x: 8; y: 42
                width: parent.width - 16
                height: parent.height - y - 6
                visible: Notifs.history.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Notifs.history

                HoverHandler { id: listHover }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: notifList.width
                    height: 52

                    Art {
                        id: rowArt
                        x: 8; y: 8
                        width: 36; height: 36
                        radius: 11
                        source: row.modelData.image
                        fallback: "notifications"
                    }
                    Column {
                        anchors.left: rowArt.right; anchors.leftMargin: 10
                        anchors.right: rowClose.left; anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Row {
                            width: parent.width
                            spacing: 6
                            Txt {
                                width: parent.width - rowTime.implicitWidth - 6
                                text: row.modelData.title !== "" ? row.modelData.title : row.modelData.app
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: row.modelData.critical ? Theme.error : Theme.fg
                            }
                            Txt {
                                id: rowTime
                                text: Qt.formatDateTime(new Date(row.modelData.time), Config.timeFormat)
                                font.pixelSize: 10
                                color: Theme.fgDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Txt {
                            width: parent.width
                            text: (row.modelData.title !== "" ? row.modelData.app + (row.modelData.body !== "" ? " · " : "") : "") + row.modelData.body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                    }
                    IconButton {
                        id: rowClose
                        anchors.right: parent.right; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 26; implicitHeight: 26
                        name: "close"; size: 15; filled: false
                        onClicked: Notifs.dismissAt(row.index)
                    }
                }
        }

        VSlider {
            id: volSlider
            x: parent.width - 150; y: 54
            width: 70; height: 210
            icon: Controls.volumeIcon
            value: Controls.volume
            dimmed: Controls.muted
            iconAction: true
            onMoved: v => Controls.setVolume(v)
            onIconClicked: Controls.toggleMute()
        }
        VSlider {
            id: briSlider
            x: parent.width - 70; y: 54
            width: 70; height: 210
            icon: "light_mode"
            value: Controls.brightness
            onMoved: v => Controls.setBrightness(v)
        }

        // ---- notifications: header + scrollable list of cards ----
        Txt { x: 2; y: 282; text: "Notifications"; font.pixelSize: 13; font.weight: Font.DemiBold }
        Item {
            x: parent.width - width; y: 278
            visible: Notifs.history.length > 0
            width: clearRow.implicitWidth + 16; height: 26
            Row {
                id: clearRow
                anchors.centerIn: parent
                spacing: 4
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "clear_all"; size: 16; color: clearMa.containsMouse ? Theme.fg : Theme.fgDim }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: "Clear all"; font.pixelSize: 11; font.weight: Font.Medium; color: clearMa.containsMouse ? Theme.fg : Theme.fgDim }
            }
            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearHistory()
            }
        }

        Column {
            x: 0; y: 318
            width: parent.width
            spacing: 8
            visible: Notifs.history.length === 0
            opacity: visible ? 1 : 0
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "notifications_none"; size: 30; color: Theme.fgDim; opacity: 0.6 }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "You're all caught up"; font.pixelSize: 12; color: Theme.fgDim; opacity: 0.8 }
        }

        ListView {
            id: notifList
            x: 0; y: 312
            width: parent.width
            height: view.height - 14 - y
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            model: ScriptModel { values: Notifs.history; objectProp: "nid" }

            HoverHandler { id: listHover }

            // smooth wheel scrolling (the island's own wheel handler must not eat it)
            NumberAnimation { id: scrollAnim; target: notifList; property: "contentY"; duration: 170; easing.type: Easing.OutCubic }
            WheelHandler {
                enabled: notifList.contentHeight > notifList.height + 1
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => {
                    const max = Math.max(0, notifList.contentHeight - notifList.height)
                    const base = scrollAnim.running ? scrollAnim.to : notifList.contentY
                    scrollAnim.stop()
                    scrollAnim.from = notifList.contentY
                    scrollAnim.to = Math.max(0, Math.min(max, base - e.angleDelta.y * 0.6))
                    scrollAnim.start()
                }
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 240 }
                    NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 300; easing.type: Easing.OutBack }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 170 }
                    NumberAnimation { property: "scale"; to: 0.92; duration: 170 }
                }
            }
            displaced: Transition { NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic } }

            delegate: NotifItem {
                width: notifList.width - (notifList.contentHeight > notifList.height + 1 ? 8 : 0)
                now: view.now
                onDismissed: Notifs.dismissId(modelData.nid)
                onInvoked: id => {
                    Notifs.invoke(modelData.nid, id)
                    Notifs.dismissId(modelData.nid)
                    view.island.closeIsland()
                }
            }
        }

        VSlider {
            id: volSlider
            x: parent.width - 150; y: 54
            width: 70; height: 210
            icon: Controls.volumeIcon
            value: Controls.volume
            dimmed: Controls.muted
            iconAction: true
            onMoved: v => Controls.setVolume(v)
            onIconClicked: Controls.toggleMute()
        }
        VSlider {
            id: briSlider
            x: parent.width - 70; y: 54
            width: 70; height: 210
            icon: "light_mode"
            value: Controls.brightness
            onMoved: v => Controls.setBrightness(v)
        }

        // ---- notifications: header + scrollable list of cards ----
        Txt { x: 2; y: 282; text: "Notifications"; font.pixelSize: 13; font.weight: Font.DemiBold }
        Item {
            x: parent.width - width; y: 278
            visible: Notifs.history.length > 0
            width: clearRow.implicitWidth + 16; height: 26
            Row {
                id: clearRow
                anchors.centerIn: parent
                spacing: 4
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "clear_all"; size: 16; color: clearMa.containsMouse ? Theme.fg : Theme.fgDim }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: "Clear all"; font.pixelSize: 11; font.weight: Font.Medium; color: clearMa.containsMouse ? Theme.fg : Theme.fgDim }
            }
            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearHistory()
            }
        }

        Column {
            x: 0; y: 318
            width: parent.width
            spacing: 8
            visible: Notifs.history.length === 0
            opacity: visible ? 1 : 0
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "notifications_none"; size: 30; color: Theme.fgDim; opacity: 0.6 }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "You're all caught up"; font.pixelSize: 12; color: Theme.fgDim; opacity: 0.8 }
        }

        ListView {
            id: notifList
            x: 0; y: 312
            width: parent.width
            height: view.height - 14 - y
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            model: ScriptModel { values: Notifs.history; objectProp: "nid" }

            HoverHandler { id: listHover }

            // smooth wheel scrolling (the island's own wheel handler must not eat it)
            NumberAnimation { id: scrollAnim; target: notifList; property: "contentY"; duration: 170; easing.type: Easing.OutCubic }
            WheelHandler {
                enabled: notifList.contentHeight > notifList.height + 1
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => {
                    const max = Math.max(0, notifList.contentHeight - notifList.height)
                    const base = scrollAnim.running ? scrollAnim.to : notifList.contentY
                    scrollAnim.stop()
                    scrollAnim.from = notifList.contentY
                    scrollAnim.to = Math.max(0, Math.min(max, base - e.angleDelta.y * 0.6))
                    scrollAnim.start()
                }
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 240 }
                    NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 300; easing.type: Easing.OutBack }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 170 }
                    NumberAnimation { property: "scale"; to: 0.92; duration: 170 }
                }
            }
            displaced: Transition { NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic } }

            delegate: NotifItem {
                width: notifList.width - (notifList.contentHeight > notifList.height + 1 ? 8 : 0)
                now: view.now
                onDismissed: Notifs.dismissId(modelData.nid)
                onInvoked: id => {
                    Notifs.invoke(modelData.nid, id)
                    Notifs.dismissId(modelData.nid)
                    view.island.closeIsland()
                }
            }
            // slim scroll indicator
            Rectangle {
                readonly property real range: Math.max(1, notifList.contentHeight - notifList.height)
                readonly property real barH: Math.max(28, notifList.height * notifList.height / Math.max(1, notifList.contentHeight))
                x: notifList.width - 3; width: 3; radius: 1.5
                height: barH
                y: notifList.contentY / range * (notifList.height - barH)
                color: Theme.fgDim
                opacity: notifList.contentHeight > notifList.height + 1 && (notifList.moving || scrollAnim.running || listHover.hovered) ? 0.5 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    // ================= picker page (Wi-Fi / Bluetooth / sound output) =================
    View {
        id: picker
        property var island: null   // no slide direction: same blur-fade morph as the island pages
        pad: 0
        dims: ({ w: view.width, h: view.height })
        active: view.sub !== ""

        // header: back, title, refresh, on/off switch
        Item {
            id: pHead
            x: 0; y: 14
            width: parent.width; height: 44

            IconButton {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 40; implicitHeight: 40
                name: "arrow_back"; size: 22; filled: false
                onClicked: view.closeSub()
            }
            Txt {
                x: 48
                anchors.verticalCenter: parent.verticalCenter
                text: view.sub === "wifi" ? "Wi-Fi" : "Bluetooth"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                IconButton {
                    id: refreshBtn
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: view.sub === "wifi" && Controls.wifi ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    implicitWidth: 36; implicitHeight: 36
                    name: "refresh"; size: 20; filled: false
                    color: Controls.wifiScanning ? Theme.primary : Theme.fg
                    onClicked: Controls.scanWifi()
                    RotationAnimator {
                        target: refreshBtn
                        from: 0; to: 360; duration: 900
                        loops: Animation.Infinite
                        running: Controls.wifiScanning && refreshBtn.visible
                        onRunningChanged: if (!running) refreshBtn.rotation = 0
                    }
                }
                // on/off switch
                Rectangle {
                    id: sw
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool on: view.sub === "wifi" ? Controls.wifi : Controls.btOn
                    width: 50; height: 30; radius: 15
                    opacity: view.sub === "bt" && !Controls.btAvailable ? 0.4 : 1
                    color: on ? Theme.primary : Theme.secondaryContainer
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        y: 4
                        x: sw.on ? parent.width - width - 4 : 4
                        color: sw.on ? Theme.primaryFg : Theme.fgDim
                        Behavior on x { SpringAnimation { spring: 7; damping: 0.55; epsilon: 0.1 } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sub === "wifi" ? Controls.toggleWifi() : Controls.toggleBluetooth()
                    }
                }
            }
        }

        Rectangle {
            id: listCard
            x: 0; y: 68
            width: parent.width
            height: parent.height - y - 14
            radius: 24
            color: Theme.card
            clip: true

            // ---- Wi-Fi ----
            View {
                id: wifiPane
                property var island: null   // no slide direction: same blur-fade morph as the island pages
                pad: 0
                dims: ({ w: listCard.width, h: listCard.height })
                active: view.sub === "wifi" && view.askSsid === ""
            ListView {
                anchors.fill: parent; anchors.margins: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Controls.wifi ? Controls.wifiList : []
                delegate: PickerRow {
                    required property var modelData
                    width: ListView.view.width
                    icon: view.wifiIcon(modelData.signal)
                    title: modelData.ssid
                    subtitle: Controls.wifiBusy === modelData.ssid ? "Working…"
                            : modelData.active ? "Connected"
                            : Controls.wifiKnown.indexOf(modelData.ssid) >= 0 ? "Saved"
                            : modelData.secure ? "Secured" : "Open"
                    selected: modelData.active
                    trailing: modelData.active ? "check" : (modelData.secure ? "lock" : "")
                    busy: Controls.wifiBusy === modelData.ssid
                    onClicked: {
                        if (modelData.active) Controls.disconnectWifi(modelData.ssid)
                        else if (modelData.secure && Controls.wifiKnown.indexOf(modelData.ssid) < 0) { view.askSsid = modelData.ssid; passInput.text = "" }
                        else Controls.connectWifi(modelData.ssid)
                    }
                }
            }
            Txt {
                anchors.centerIn: parent
                visible: (!Controls.wifi || Controls.wifiList.length === 0)
                color: Theme.fgDim
                text: !Controls.wifi ? "Wi-Fi is off" : (Controls.wifiScanning ? "Searching…" : "No networks found")
            }
            Txt {
                x: 18; y: parent.height - 30
                width: parent.width - 36
                visible: Controls.wifiMsg !== ""
                text: Controls.wifiMsg
                font.pixelSize: 11
                color: Theme.error
            }
            }

            // password prompt for a new secured network
            View {
                id: passPane
                property var island: null   // no slide direction: same blur-fade morph as the island pages
                pad: 0
                dims: ({ w: listCard.width, h: listCard.height })
                active: view.sub === "wifi" && view.askSsid !== ""

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 12
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "lock"; size: 26; color: Theme.fgDim }
                    Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: view.askSsid; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Rectangle {
                        width: parent.width; height: 42; radius: 21
                        color: Theme.bg
                        border.width: passInput.activeFocus ? 1 : 0
                        border.color: Theme.primary
                        TextInput {
                            id: passInput
                            anchors.fill: parent
                            anchors.leftMargin: 18; anchors.rightMargin: 18
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 14
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryFg
                            clip: true
                            Keys.onReturnPressed: go()
                            Keys.onEnterPressed: go()
                            Keys.onEscapePressed: view.askSsid = ""
                            function go() {
                                if (text === "") return
                                Controls.connectWifi(view.askSsid, text)
                                view.askSsid = ""
                                text = ""
                            }
                            Txt { anchors.verticalCenter: parent.verticalCenter; visible: parent.text === ""; text: "Password"; color: Theme.fgDim; font.pixelSize: 14 }
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        Rectangle {
                            width: 110; height: 38; radius: 19
                            color: cancelMa.containsMouse ? Theme.cardHi : Theme.secondaryContainer
                            Txt { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 13; font.weight: Font.Medium }
                            MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.askSsid = "" }
                        }
                        Rectangle {
                            width: 110; height: 38; radius: 19
                            color: Theme.primary
                            opacity: passInput.text === "" ? 0.5 : 1
                            Txt { anchors.centerIn: parent; text: "Connect"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.primaryFg }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: passInput.go() }
                        }
                    }
                }
            }

            // ---- Bluetooth ----
            View {
                id: btPane
                property var island: null   // no slide direction: same blur-fade morph as the island pages
                pad: 0
                dims: ({ w: listCard.width, h: listCard.height })
                active: view.sub === "bt"
            ListView {
                anchors.fill: parent; anchors.margins: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Controls.btList
                delegate: PickerRow {
                    required property var modelData
                    readonly property bool working: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                    width: ListView.view.width
                    icon: view.btIcon(modelData)
                    title: modelData.name
                    subtitle: working ? "Working…"
                            : modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                            : modelData.paired ? "Paired" : "Tap to pair"
                    selected: modelData.connected
                    trailing: modelData.connected ? "check" : ""
                    busy: working
                    onClicked: Controls.btActivate(modelData)
                }
            }
            Txt {
                anchors.centerIn: parent
                visible: (!Controls.btOn || Controls.btList.length === 0)
                color: Theme.fgDim
                text: !Controls.btAvailable ? "No Bluetooth adapter" : (!Controls.btOn ? "Bluetooth is off" : "Searching…")
            }
            }
        }
    }
}
