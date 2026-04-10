import Foundation

/// Posted when the shared scroll fraction changes (editor ↔ preview sync).
extension Notification.Name {
    /// Toggle the box-character palette strip (editor mode).
    static let clearlyToggleBlueprint = Notification.Name("ClearlyToggleBlueprint")

    /// Toggle the MASTER notes strip (editor mode).
    static let clearlyToggleMasterStrip = Notification.Name("ClearlyToggleMasterStrip")

    static let clearlySharedScrollFractionChanged = Notification.Name("ClearlySharedScrollFractionChanged")
}

/// Source for `clearlySharedScrollFractionChanged` (`userInfo["source"]`).
enum ScrollFractionSource: Int {
    case editor = 0
    case preview = 1
    case align = 2
}
