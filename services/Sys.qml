pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// System monitor state: CPU, memory, network, temperature, disk, GPU, top processes.
// Nothing is polled unless `watching` is true (SysView sets it while it is on screen),
// so the resting island costs nothing.
Singleton {
    id: root

    property bool watching: false
    readonly property int histLen: 60

    // ---- cpu (percent 0..100) ----
    property real cpu: 0
    property var cpuHist: []
    property real temp: -1                 // deg C, -1 = no sensor found

    // ---- memory (KiB) ----
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memPct: memTotal > 0 ? memUsed / memTotal * 100 : 0

    // ---- disk (bytes, "/") ----
    property real diskTotal: 0
    property real diskUsed: 0
    readonly property real diskPct: diskTotal > 0 ? diskUsed / diskTotal * 100 : 0

    // ---- gpu (percent, -1 = none found) ----
    property real gpu: -1

    // ---- network (bytes / second, all real interfaces summed) ----
    property real rx: 0
    property real tx: 0

    // ---- misc ----
    property string uptime: ""
    property string load: ""

    // ---- top processes: [{ name, cpu, mem }] ----
    property bool sortByMem: false
    property var procs: []

    // ---- formatting helpers ----
    // { n: "4.7", u: "GB" }: number and unit apart so the UI can style them separately
    function bytesParts(b) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return { n: (b >= 100 || i === 0 ? b.toFixed(0) : b.toFixed(1)), u: u[i] }
    }
    function fmtBytes(b) { const p = bytesParts(b); return p.n + " " + p.u }
    // "4.7 of 15.5 GB": both numbers in the total's unit
    function fmtPair(used, total) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0, t = total
        while (t >= 1024 && i < u.length - 1) { t /= 1024; i++ }
        const d = Math.pow(1024, i)
        const f = x => (t >= 100 || i === 0 ? (x / d).toFixed(0) : (x / d).toFixed(1))
        return f(used) + " of " + f(total) + " " + u[i]
    }
    function fmtRate(b) { return fmtBytes(b) + "/s" }
    function fmtKiB(k) { return fmtBytes(k * 1024) }

    onWatchingChanged: {
        // start a fresh delta window so the first sample after re-opening isn't an hours-long average
        _prevTotal = -1
        _netT = 0
    }

    // =====================================================================
    //  fast loop: /proc/stat, meminfo, net/dev, uptime, loadavg (one cheap `sh`)
    // =====================================================================
    property real _prevIdle: 0
    property real _prevTotal: -1
    property real _prevRx: 0
    property real _prevTx: 0
    property real _netT: 0

    Timer {
        interval: Math.max(500, Config.sysmonInterval)
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!fast.running) fast.running = true
    }

    Process {
        id: fast
        command: ["sh", "-c",
            "echo @stat; head -n 1 /proc/stat; " +
            "echo @mem; head -n 25 /proc/meminfo; " +
            "echo @net; cat /proc/net/dev; " +
            "echo @up; cat /proc/uptime; " +
            "echo @load; cat /proc/loadavg"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFast(text)
        }
    }

    function parseFast(text) {
        const lines = text.split("\n")
        let sec = ""
        const mem = {}
        let rxB = 0, txB = 0, haveNet = false

        for (const raw of lines) {
            const line = raw.trim()
            if (line === "") continue
            if (line[0] === "@") { sec = line; continue }

            if (sec === "@stat") {
                // cpu  user nice system idle iowait irq softirq steal ...
                const f = line.split(/\s+/).slice(1).map(Number)
                if (f.length >= 5) {
                    const idle = f[3] + (f[4] || 0)
                    let total = 0
                    for (let i = 0; i < Math.min(8, f.length); i++) total += f[i]
                    if (_prevTotal >= 0 && total > _prevTotal) {
                        const dt = total - _prevTotal
                        const di = idle - _prevIdle
                        cpu = Math.max(0, Math.min(100, (1 - di / dt) * 100))
                        const h = cpuHist.slice(-(histLen - 1))
                        h.push(cpu)
                        cpuHist = h
                    }
                    _prevIdle = idle
                    _prevTotal = total
                }
            } else if (sec === "@mem") {
                const m = line.match(/^(\w+):\s+(\d+)/)
                if (m) mem[m[1]] = Number(m[2])
            } else if (sec === "@net") {
                const m = line.match(/^([^:\s]+):\s*(.*)$/)
                if (!m) continue
                const name = m[1]
                if (name === "lo" || name.startsWith("veth") || name.startsWith("docker") || name.startsWith("br-")) continue
                const f = m[2].split(/\s+/)
                if (f.length >= 9) { rxB += Number(f[0]); txB += Number(f[8]); haveNet = true }
            } else if (sec === "@up") {
                uptime = fmtUptime(parseFloat(line))
            } else if (sec === "@load") {
                const p = line.split(/\s+/)
                load = p.slice(0, 3).join("  ")
            }
        }

        if (mem.MemTotal !== undefined) {
            memTotal = mem.MemTotal
            memUsed = mem.MemTotal - (mem.MemAvailable !== undefined ? mem.MemAvailable : (mem.MemFree || 0))
            swapTotal = mem.SwapTotal || 0
            swapUsed = swapTotal - (mem.SwapFree || 0)
        }

        if (haveNet) {
            const now = Date.now()
            if (_netT > 0 && now > _netT) {
                const s = (now - _netT) / 1000
                rx = Math.max(0, (rxB - _prevRx) / s)     // counters can reset when an interface goes away
                tx = Math.max(0, (txB - _prevTx) / s)
            }
            _prevRx = rxB
            _prevTx = txB
            _netT = now
        }
    }

    function fmtUptime(s) {
        const d = Math.floor(s / 86400)
        const h = Math.floor(s % 86400 / 3600)
        const m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m"
    }

    // =====================================================================
    //  slow loop: temperature, disk, GPU (sysfs + df + nvidia-smi if present)
    // =====================================================================
    Timer {
        interval: 5000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!slow.running) slow.running = true
    }

    readonly property string slowScript: [
        "t=''",
        "for h in /sys/class/hwmon/hwmon*; do",
        "  case $(cat $h/name 2>/dev/null) in",
        "    coretemp|k10temp|zenpower|cpu_thermal) t=$(cat $h/temp1_input 2>/dev/null); [ -n \"$t\" ] && break;;",
        "  esac",
        "done",
        "[ -z \"$t\" ] && t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)",
        "echo \"temp=$t\"",
        "echo \"disk=$(df -PB1 / | awk 'NR==2{print $3, $2}')\"",
        "g=''",
        "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && { g=$(cat $f); break; }; done",
        "if [ -z \"$g\" ] && command -v nvidia-smi >/dev/null 2>&1; then",
        "  g=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)",
        "fi",
        "echo \"gpu=$g\""
    ].join("\n")

    Process {
        id: slow
        command: ["sh", "-c", root.slowScript]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const raw of text.split("\n")) {
                    const i = raw.indexOf("=")
                    if (i < 0) continue
                    const k = raw.slice(0, i), v = raw.slice(i + 1).trim()
                    if (k === "temp") root.temp = v !== "" && !isNaN(v) ? Number(v) / 1000 : -1
                    else if (k === "gpu") root.gpu = v !== "" && !isNaN(v) ? Number(v) : -1
                    else if (k === "disk") {
                        const p = v.split(/\s+/).map(Number)
                        if (p.length >= 2 && p[1] > 0) { root.diskUsed = p[0]; root.diskTotal = p[1] }
                    }
                }
            }
        }
    }

    // =====================================================================
    //  top processes: second iteration of `top` is an instantaneous reading
    //  (ps' %cpu is a lifetime average, which is misleading here)
    // =====================================================================
    Timer {
        interval: 3000
        running: root.watching && Config.sysmonProcesses > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!topProc.running) topProc.running = true
    }

    Process {
        id: topProc
        command: ["sh", "-c",
            "LC_ALL=C top -b -n 2 -d 0.6 -w 512 -o " + (root.sortByMem ? "%MEM" : "%CPU") + " 2>/dev/null | " +
            "awk '/^top -/{n++} n==2 && /^ *[0-9]+ /{c=$12; for(i=13;i<=NF;i++) c=c\" \"$i; print $9 \"|\" $10 \"|\" c}' | " +
            "head -n " + Math.max(1, Math.min(6, Config.sysmonProcesses))]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length < 3) continue
                    out.push({ cpu: Number(p[0]) || 0, mem: Number(p[1]) || 0, name: p.slice(2).join("|") })
                }
                root.procs = out
            }
        }
    }

    function setSort(byMem) {
        if (sortByMem === byMem) return
        sortByMem = byMem
        procs = []
        if (!topProc.running) topProc.running = true
    }
}
