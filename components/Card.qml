import QtQuick
import qs.config

// Soft rounded surface: a faint wash of foreground + matugen primary, with a hairline edge.
Rectangle {
    radius: 22
    color: Qt.rgba((Theme.fg.r + Theme.primary.r) / 2, (Theme.fg.g + Theme.primary.g) / 2, (Theme.fg.b + Theme.primary.b) / 2, 0.10)
    border.width: 1
    border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.05)
}
