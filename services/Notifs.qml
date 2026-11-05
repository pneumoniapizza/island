pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// NOTE: only one notification daemon can own org.freedesktop.Notifications.
// Stop mako/swaync/other shells' servers before running this.
Singleton {
    id: root

    property string title: ""
    property string body: ""
    property string app: ""
    property string image: ""
    property bool critical: false
    property var current: null
    property bool dnd: false
    signal arrived()

    // recent notifications for the control center, newest first.
    // each entry: { nid, app, title, body, image, critical, time, actions: [{id, text}], hasDefault }
    // The live Notification objects stay tracked in _live (keyed by nid) while an entry is in the
    // list, so its action buttons keep working; dismissing / clearing an entry closes it for real.
    property var history: []
    readonly property int historyMax: 30
    property var _live: ({})
    property int _seq: 0

    function _release(e) {
        const n = _live[e.nid]
        if (!n) return
        delete _live[e.nid]
        try { n.dismiss() } catch (err) {}
    }
    function remember(entry) {
        const list = [entry].concat(history)
        list.slice(historyMax).forEach(_release)
        history = list.slice(0, historyMax)
    }
    function dismissId(nid) {
        const e = history.find(x => x.nid === nid)
        if (e) _release(e)
        history = history.filter(x => x.nid !== nid)
    }
    function dismissAt(i) { if (history[i]) dismissId(history[i].nid) }
    function clearHistory() {
        history.forEach(_release)
        history = []
    }
    // run one of the notification's own actions ("default" = the click action)
    function invoke(nid, actionId) {
        const n = _live[nid]
        if (!n) return false
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === actionId) {
                try { n.actions[i].invoke() } catch (err) { return false }
                return true
            }
        }
        return false
    }
    // the app closed it itself: keep the text in the list but drop the dead buttons
    function _closedByApp(nid) {
        if (!_live[nid]) return
        delete _live[nid]
        history = history.map(e => e.nid === nid ? Object.assign({}, e, { actions: [], hasDefault: false }) : e)
    }

    // hides the banner only; the notification itself stays in the list
    function clear() { current = null }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true

            let img = n.image
            if (!img && n.appIcon)
                img = n.appIcon.startsWith("/") ? n.appIcon : Quickshell.iconPath(n.appIcon, true)

            const acts = []
            let hasDefault = false
            for (let i = 0; i < n.actions.length; i++) {
                const id = n.actions[i].identifier
                if (id === "default") hasDefault = true
                else acts.push({ id: id, text: n.actions[i].text })
            }
            const nid = ++root._seq
            root._live[nid] = n
            n.closed.connect(() => root._closedByApp(nid))

            // logged in the control center even when Focus swallows the banner
            root.remember({
                nid: nid,
                app: n.appName,
                title: n.summary,
                body: n.body,
                image: img ?? "",
                critical: n.urgency === NotificationUrgency.Critical,
                time: Date.now(),
                actions: acts,
                hasDefault: hasDefault
            })

            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return
            root.clear()
            root.current = n
            root.title = n.summary
            root.body = n.body
            root.app = n.appName
            root.critical = n.urgency === NotificationUrgency.Critical
            root.image = img ?? ""
            root.arrived()
        }
    }
}
