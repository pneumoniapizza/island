import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components
import "views"

// The island window: owns the state (what is showing, hover, timers) and the pill.
// Every state the pill can show lives in views/ (one file each).
PanelWindow {
    id: root

    // ---- geometry table (pill size per mode) ----
    readonly property int topGap: Config.topGap
    readonly property int liveExtraW: (Countdown.active ? 68 : 0) + (Privacy.active ? 14 : 0)
    readonly property var sizes: ({
        idle:   { w: 132 + liveExtraW, h: 34  },
        media:  { w: 226 + liveExtraW, h: 38  },
        osd:    { w: Osd.label !== "" ? 340 : 300, h: 48  },
        peek:   { w: 390, h: 72  },
        notif:  { w: 430, h: 84  },
        hub:    { w: 360, h: 112 },
        timer:  { w: 390, h: 142 },
        player: { w: 460, h: 192 },
        center: { w: 460, h: 482 },
        power:  { w: 560, h: 140 },
        // pages that size themselves
        walls:     { w: wallpaperView.wantW, h: wallpaperView.wantH },
        launcher:  { w: launcherView.wantW,  h: launcherView.wantH },
        clipboard: { w: clipboardView.wantW, h: clipboardView.wantH },
        emoji:     { w: emojiView.wantW,     h: emojiView.wantH },
        calendar:  { w: calendarView.wantW,  h: calendarView.wantH },
        tray:      { w: trayView.wantW,      h: trayView.wantH }
    })

    // shared cover art: ONE item that morphs between layouts
    readonly property var artGeom: ({
        media:  { s: 24, y: 7,  show: true  },
        peek:   { s: 46, y: 13, show: true  },
        notif:  { s: 48, y: 18, show: true  },
        player: { s: 72, y: 16, show: true  }
    })
    readonly property var ag: artGeom[mode] ?? ({ x: 16, s: 24, y: 7, show: false })

    // ---- window ----
    anchors.top: true
    implicitWidth: Math.max(sizes.player.w, sizes.walls.w, sizes.center.w, sizes.power.w, sizes.launcher.w, sizes.clipboard.w, sizes.timer.w, sizes.emoji.w, sizes.calendar.w, sizes.tray.w) + 80
    implicitHeight: topGap + Math.max(sizes.center.h, sizes.walls.h, 70 + Config.launcherRows * 52 + 14, 70 + Config.clipboardRows * 52 + 14, 108 + Config.emojiRows * Math.floor((sizes.emoji.w - 32) / Config.emojiColumns) + 52, sizes.calendar.h, sizes.tray.h) + 56
    color: "transparent"
    // reserve space for the idle pill only; expanded states float over windows.
    // Your compositor adds its own window gap on top of this, so with windowGap = 0 the
    // space between the pill and the first window equals the gap between windows.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Math.max(0, topGap + sizes.idle.h + Config.windowGap)
    // Top sits below fullscreen windows (the bar hides with them); Overlay only while something is actually showing
    WlrLayershell.layer: (expanded || (!fsActive && (osdOn || notifOn || peekOn || Countdown.ringing))) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "island"
    WlrLayershell.keyboardFocus: (root.mode === "launcher" || root.mode === "walls" || root.mode === "clipboard" || root.mode === "power" || root.mode === "timer" || root.mode === "emoji" || root.mode === "calendar" || centerView.typing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: pill }

    // ---- state ----
    property bool hoverRaw: false
    property bool expanded: false
    property bool osdOn: false
    property bool notifOn: false
    property bool peekOn: false
    // focused window is fullscreen: no automatic popups (peek, OSD, notifications, timer ring); only user-opened pages show
    readonly property bool fsActive: ToplevelManager.activeToplevel !== null && ToplevelManager.activeToplevel !== undefined && ToplevelManager.activeToplevel.fullscreen
    onFsActiveChanged: if (fsActive) { peekOn = false; peekTimer.stop(); osdOn = false; osdTimer.stop(); notifOn = false; notifTimer.stop() }
    property string page: "main"   // main | center | walls | launcher | clipboard | power | timer | emoji | calendar | tray
    // launcher, wallpaper, clipboard, power and timer pages grab the keyboard and stay open until closed
    readonly property bool modal: page === "launcher" || page === "walls" || page === "clipboard" || page === "power" || page === "timer" || page === "emoji" || page === "calendar"

    // directional transition state between sibling expanded pages (-1 = left, 0 = vertical, 1 = right)
    readonly property var modeSlots: ({
        launcher: 1, clipboard: 2, emoji: 3, calendar: 4, timer: 5, hub: 6, player: 6, tray: 7, center: 8, walls: 9, power: 10
    })
    property int _lastSlot: 0
    property int navDir: 0
    function _resolveMode() {
        if (expanded && page === "launcher") return "launcher"
        if (expanded && page === "clipboard") return "clipboard"
        if (expanded && page === "power") return "power"
        if (expanded && page === "timer") return "timer"
        if (expanded && page === "emoji") return "emoji"
        if (expanded && page === "calendar") return "calendar"
        if (Countdown.ringing && !fsActive) return "timer"
        if (notifOn) return "notif"
        if (expanded) return page === "center" ? "center" : page === "walls" ? "walls" : page === "tray" ? "tray" : (hasMedia ? "player" : (Countdown.active ? "timer" : "hub"))
        if (osdOn) return "osd"
        if (peekOn && hasMedia) return "peek"
        if (mediaPlaying && Config.pillExpandOnMedia) return "media"
        return "idle"
    }

    // vim state (shared by launcher / clipboard / wallpapers: only one is ever active)
    property bool vimNormal: false     // launcher only: normal vs insert mode
    property string vimPending: ""     // first key of a two-key chord (g, d)
    property int vimCount: 0           // numeric prefix, e.g. 3j
    readonly property bool overSlider: centerView.overSlider

    // scrubbing: drag only moves a local ratio; the seek is sent once, on release
    property bool scrubbing: false
    property bool holdSeek: false
    property real scrubRatio: 0
    readonly property real shownRatio: (scrubbing || holdSeek) ? scrubRatio : progress
    readonly property real trackLen: hasMedia && player.length > 0 ? player.length : 0

    readonly property var player: Media.active
    readonly property bool hasMedia: player !== null && player !== undefined
    readonly property bool mediaPlaying: hasMedia && player.isPlaying
    readonly property string title: hasMedia && player.trackTitle ? player.trackTitle : "Nothing playing"
    readonly property string artist: hasMedia && player.trackArtist ? player.trackArtist : ""
    readonly property string artUrl: hasMedia && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real progress: hasMedia && player.length > 0 ? Math.min(1, player.position / player.length) : 0

    readonly property string batteryIcon: {
        const d = UPower.displayDevice
        if (!d || !d.isPresent) return "battery_unknown"
        if (d.state === UPowerDeviceState.Charging) return "battery_charging_full"
        const p = d.percentage
        return p > 0.85 ? "battery_full" : p > 0.7 ? "battery_6_bar" : p > 0.55 ? "battery_5_bar"
             : p > 0.4 ? "battery_4_bar" : p > 0.25 ? "battery_3_bar" : p > 0.1 ? "battery_2_bar" : "battery_alert"
    }

    // battery as a pill icon (pill.batteryIcon); hidden on machines without one
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice !== undefined && UPower.displayDevice.isPresent
    readonly property bool pillBattery: Config.pillBatteryIcon && hasBattery
    readonly property color batteryColor: {
        const d = UPower.displayDevice
        if (!d || !d.isPresent) return Theme.fg
        if (d.state === UPowerDeviceState.Charging) return Theme.primary
        return d.percentage <= 0.15 ? Theme.error : Theme.fg
    }

    // priority: modal pages > ringing timer > notification > hover > osd > track-change peek > playing > idle
    // pure: no side effects inside the binding (writing _lastSlot/navDir here caused the binding loop)
    readonly property string _target: _resolveMode()
    // plain property, only ever assigned from onTargetChanged below, after navDir is up to date
    property string mode: _resolveMode()
    on_TargetChanged: {
        const s = modeSlots[_target] ?? 0
        if (s !== _lastSlot) {
            navDir = (_lastSlot > 0 && s > 0) ? (s > _lastSlot ? 1 : -1) : 0
            _lastSlot = s
        }
        mode = _target
    }

    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    function commitSeek() {
        scrubbing = false
        if (hasMedia && player.canSeek && trackLen > 0) {
            player.position = scrubRatio * trackLen
            holdSeek = true            // keep showing the target until the player catches up
            holdTimer.restart()
        }
    }

    IdleInhibitor { window: root; enabled: Controls.keepAwake }

    onExpandedChanged: if (!expanded) page = "main"
    onModeChanged: {
        if (mode === "center") Controls.refresh()
        vimReset()
        if (mode === "launcher") launcherView.shown()
        if (mode === "clipboard") clipboardView.shown()
        if (mode === "power") powerView.shown()
        if (mode === "walls") wallpaperView.shown()
        if (mode === "timer") timerView.shown()
        if (mode === "emoji") emojiView.shown()
        if (mode === "calendar") calendarView.shown()
        if (mode === "tray") trayView.shown()
        if (mode !== "player") { scrubbing = false; holdSeek = false }
    }

    Connections { target: Osd;    function onTriggered()    { if (!root.fsActive && root.mode !== "center" && root.mode !== "walls" && root.mode !== "launcher" && root.mode !== "clipboard" && root.mode !== "power" && root.mode !== "timer" && root.mode !== "emoji" && root.mode !== "calendar") { root.osdOn = true; osdTimer.restart() } } }
    Connections { target: Media;  function onTrackChanged() { if (!Config.mediaPeek || root.fsActive) return; root.peekOn = true;  peekTimer.restart()  } }
    Connections {
        target: Notifs
        function onArrived() {
            if (root.fsActive) return
            root.notifOn = true
            if (root.hoverRaw) notifTimer.stop(); else notifTimer.restart()
        }
    }

    Timer { id: osdTimer;   interval: Config.osdTimeout; onTriggered: root.osdOn = false }
    Timer { id: notifTimer; interval: Config.notifTimeout; onTriggered: { root.notifOn = false; Notifs.clear() } }
    Timer { id: holdTimer;  interval: 900;  onTriggered: root.holdSeek = false }
    Timer { id: peekTimer;  interval: Config.peekTimeout; onTriggered: root.peekOn = false }
    Timer { id: enterTimer; interval: Config.hoverDelay;  onTriggered: root.expanded = true }
    Timer { id: leaveTimer; interval: Config.leaveDelay;  onTriggered: if (!root.modal && !centerView.typing) root.expanded = false }

    // Switching pages while the cursor is on the island can resize the pill (e.g. control center -> tray),
    // dropping the cursor outside it. That is not the user leaving, so ignore hover loss until the
    // resize settles; the pill then closes only after the cursor has entered it and left again.
    property bool settling: false
    Timer { id: settleTimer; interval: 900; onTriggered: root.settling = false }
    onPageChanged: if (expanded && hoverRaw) { settling = true; settleTimer.restart() }

    // ---- IPC: open / toggle / close a page ----
    Timer { id: ipcTimer; interval: Config.ipcTimeout; onTriggered: if (!root.hoverRaw && !centerView.typing) root.expanded = false }
    function openPage(p) {
        if (["main", "center", "walls", "launcher", "clipboard", "power", "timer", "emoji", "calendar", "tray"].indexOf(p) < 0) p = "center"
        page = p
        expanded = true
        // modal pages and the tray stay open until you use them: the tray has no timeout,
        // it only closes once the cursor has entered it and left again (or via IPC / a click)
        if (modal || p === "tray") ipcTimer.stop(); else ipcTimer.restart()
    }
    function closeIsland() { ipcTimer.stop(); expanded = false }

    // ---- vim helpers ----
    function vimReset() { vimPending = ""; vimCount = 0 }


    Connections {
        target: Ui
        function onOpenRequested(p) { root.openPage(p) }
        function onToggleRequested(p) { if (root.expanded && root.page === p) root.closeIsland(); else root.openPage(p) }
        function onCloseRequested() { root.closeIsland() }
    }

    // MPRIS position isn't pushed; poll while the player is visible
    Timer {
        interval: 250
        repeat: true
        running: root.mode === "player" && root.mediaPlaying
        onTriggered: root.player.positionChanged()
    }

    // ======================= shadow =======================
    // Drawn separately from the pill and kept off the very top row of the screen: the blur
    // used to leave a thin dark line there. The shadow still fades out naturally above the pill.
    Item {
        id: shadowClip
        visible: Config.shadow
        x: 0
        y: Math.min(pill.y, 1)
        width: root.width
        height: Math.max(0, root.height - y)
        clip: true

        ClippingRectangle {
            x: pill.x
            y: pill.y - shadowClip.y
            width: pill.width
            height: pill.height
            radius: pill.radius
            topLeftRadius: pill.topLeftRadius
            topRightRadius: pill.topRightRadius
            color: Theme.bg
            transformOrigin: Item.Top
            scale: pill.scale

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Config.shadowColor
                shadowOpacity: Config.shadowOpacity
                shadowBlur: Config.shadowBlur
                shadowVerticalOffset: Config.shadowOffset
            }
        }
    }

    // ======================= the island =======================
    ClippingRectangle {
        id: pill

        readonly property var dim: root.sizes[root.mode]
        readonly property bool anticipating: Config.hoverToExpand && root.hoverRaw && !root.expanded
                                             && (root.mode === "idle" || root.mode === "media")

        y: root.topGap
        anchors.horizontalCenter: parent.horizontalCenter
        width: dim.w
        height: dim.h
        radius: Math.min(height / 2, 36)
        topLeftRadius: Config.notch ? 0 : radius
        topRightRadius: Config.notch ? 0 : radius
        color: Theme.bg
        border.width: Theme.light ? 1 : 0     // thin edge so a light pill doesn't vanish on light windows
        border.color: Theme.outline

        transformOrigin: Item.Top
        scale: anticipating ? 1.07 : 1.0

        // spring morph: height snappier than width, like iOS
        Behavior on width  { SpringAnimation { spring: 3.6; damping: 0.40; epsilon: 0.15 } }
        Behavior on height { SpringAnimation { spring: 4.4; damping: 0.46; epsilon: 0.15 } }
        Behavior on scale  { SpringAnimation { spring: 7.0; damping: 0.45; epsilon: 0.001 } }

        HoverHandler {
            onHoveredChanged: {
                root.hoverRaw = hovered
                if (hovered) {
                    leaveTimer.stop(); if (Config.hoverToExpand) enterTimer.restart()
                    if (root.notifOn) notifTimer.stop()
                } else {
                    enterTimer.stop(); if (!root.settling) leaveTimer.restart()
                    if (root.notifOn) notifTimer.restart()
                }
            }
        }

        TapHandler {
            onTapped: if (root.mode === "notif") { root.notifOn = false; Notifs.clear() }
        }

        // scroll down = control center, scroll up = back (wallpaper page scrolls its own list)
        WheelHandler {
            onWheel: e => { if (root.expanded && !root.notifOn && !root.modal && !(root.mode === "center" && root.overSlider)) root.page = e.angleDelta.y < 0 ? "center" : "main" }
        }

        // ===== views (one file each in views/) =====
        IdleView      { id: idleView;      island: root }
        MediaView     { id: mediaView;     island: root }
        PeekView      { id: peekView;      island: root }
        OsdView       { id: osdView;       island: root }
        NotifView     { id: notifView;     island: root }
        HubView       { id: hubView;       island: root }
        TimerView     { id: timerView;     island: root }
        PlayerView    { id: playerView;    island: root }
        CenterView    { id: centerView;    island: root }
        WallpaperView { id: wallpaperView; island: root }
        LauncherView  { id: launcherView;  island: root }
        ClipboardView { id: clipboardView; island: root }
        PowerView     { id: powerView;     island: root }
        EmojiView     { id: emojiView;     island: root }
        CalendarView  { id: calendarView;  island: root }
        TrayView      { id: trayView;      island: root }

        // ===== shared cover art (morphs between all layouts) =====
        Art {
            id: cover
            x: root.ag.x ?? 16
            y: root.ag.y
            width: root.ag.s
            height: root.ag.s
            radius: Math.round(width * 0.3)
            opacity: root.ag.show ? 1 : 0
            source: root.mode === "notif" ? Notifs.image : root.artUrl
            fallback: root.mode === "notif" ? "notifications" : "music_note"

            Behavior on x      { SpringAnimation { spring: 4.2; damping: 0.45; epsilon: 0.1 } }
            Behavior on y      { SpringAnimation { spring: 4.2; damping: 0.45; epsilon: 0.1 } }
            Behavior on width  { SpringAnimation { spring: 4.2; damping: 0.45; epsilon: 0.1 } }
            Behavior on height { SpringAnimation { spring: 4.2; damping: 0.45; epsilon: 0.1 } }
            Behavior on opacity { NumberAnimation { duration: root.ag.show ? 260 : 110; easing.type: Easing.OutCubic } }
        }
    }
}
