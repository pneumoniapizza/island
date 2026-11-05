//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.ipc
import qs.modules.island
import qs.modules.lock

ShellRoot {
    Component.onCompleted: Clip.refresh()      // also instantiates Clip so its watchers start

    // one island per screen
    Variants {
        model: Quickshell.screens
        Island {
            required property var modelData
            screen: modelData
        }
    }

    // ---- lock screen (ext-session-lock): one surface per monitor while locked ----
    WlSessionLock {
        locked: Lock.locked
        WlSessionLockSurface {
            color: Theme.bg
            LockView { anchors.fill: parent }
        }
    }

    // ---- auto-lock after the idle timeout (the Awake toggle inhibits it) ----
    IdleMonitor {
        enabled: Config.autoLock && !Lock.locked
        timeout: Config.lockTimeout
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Lock.lock()
    }

    Ipc {}
}
