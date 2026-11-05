import Quickshell.Io
import qs.services

// qs -c island ipc call sysmon toggle | open | close
IpcHandler {
    target: "sysmon"
    function open(): void { Ui.openRequested("sysmon") }
    function close(): void { Ui.closeRequested() }
    function toggle(): void { Ui.toggleRequested("sysmon") }
}
