import Quickshell.Io
import qs.services

// qs -c island ipc call island brightness "5%+"
// qs -c island ipc call island open walls        (main | center | walls | launcher | clipboard | power | timer | emoji | calendar | tray | sysmon)
// qs -c island ipc call island toggle launcher
// qs -c island ipc call island close
// qs -c island ipc call island help          (prints every command)
// qs -c island ipc show                      (raw list of targets + functions)
IpcHandler {
    target: "island"
    function brightness(delta: string): void { Osd.brightness(delta) }
    function open(page: string): void { Ui.openRequested(page) }
    function toggle(page: string): void { Ui.toggleRequested(page) }
    function close(): void { Ui.closeRequested() }
    function help(): string {
        return [
            "island ipc  (nix: `island ipc call ...`, `island --ipc` lists everything)",
            "  island    brightness <delta> | open <main|center|walls|launcher|clipboard|power|timer|emoji|calendar|tray|sysmon> | toggle <page> | close | help",
            "  launcher  open | toggle | close",
            "  clipboard open | toggle | close | wipe",
            "  emoji     open | toggle | close | clearRecent",
            "  calendar  open | toggle | close",
            "  tray      open | toggle | close",
            "  sysmon    open | toggle | close",
            "  center    open | toggle | close",
            "  timer     open | toggle | close | start <25m|300> | add <1m> | pause | resume | playPause | reset | status",
            "  power     open | toggle | close | lock | logout | suspend | reboot | poweroff",
            "  wallpaper next | prev | random | restore | refresh | set <path> | mode <dark|light> | scheme <name> | contrast <-1..1> | accent <#hex|auto> | current | open | toggle | close"
        ].join("\n")
    }
}
