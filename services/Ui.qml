pragma Singleton
import QtQuick
import Quickshell

// Requests from IPC to the island windows
Singleton {
    signal openRequested(string page)     // main | center | walls | launcher | clipboard | power | timer | emoji | calendar | tray | sysmon
    signal toggleRequested(string page)
    signal closeRequested()
}
