import Foundation

/// Line-number-based scroll position storage for mode-switch persistence.
/// This is stable regardless of layout state (line 200 is always line 200).
enum ScrollPositionStore {
    struct Position {
        let firstVisibleLine: Int
        let fractionalLine: CGFloat
    }
    private static var positions: [String: Position] = [:]
    static func save(_ pos: Position, for id: String) { positions[id] = pos }
    static func restore(for id: String) -> Position? { positions[id] }
}

struct PreviewSourceAnchor: Hashable {
    let startLine: Int
    let startColumn: Int
    let endLine: Int
    let endColumn: Int
    let progress: Double

    var approximateLine: Double {
        let span = max(0, endLine - startLine)
        return Double(startLine) + (Double(span) * progress)
    }
}

/// Scroll position storage keyed per document window (`positionSyncID`).
/// Editor and preview always share one linked scroll fraction (`shared`).
enum ScrollBridge {
    private static var fractions: [String: Double] = [:]
    /// WK posts scroll on the main thread; apply to `NSScrollView` here instead of waiting for SwiftUI+relay.
    private static var previewToEditorScrollHandlers: [String: (Double) -> Void] = [:]

    private static func editorKey(_ id: String) -> String { "\(id)#editor" }
    private static func previewKey(_ id: String) -> String { "\(id)#preview" }

    /// Linked scroll position (sync enabled).
    static func sharedFraction(for id: String) -> Double {
        fractions[id] ?? 0
    }

    static func setSharedFraction(_ value: Double, for id: String, notify: ScrollFractionSource? = nil) {
        let v = min(1, max(0, value))
        fractions[id] = v
        if let notify {
            NotificationCenter.default.post(
                name: .clearlySharedScrollFractionChanged,
                object: nil,
                userInfo: ["id": id, "fraction": v, "source": notify.rawValue]
            )
        }
    }

    /// Editor-only position (sync disabled).
    static func editorFraction(for id: String) -> Double {
        fractions[editorKey(id)] ?? 0
    }

    static func setEditorFraction(_ value: Double, for id: String) {
        fractions[editorKey(id)] = min(1, max(0, value))
    }

    /// Preview-only position (sync disabled).
    static func previewFraction(for id: String) -> Double {
        fractions[previewKey(id)] ?? 0
    }

    static func setPreviewFraction(_ value: Double, for id: String) {
        fractions[previewKey(id)] = min(1, max(0, value))
    }

    /// Legacy: maps to shared (used where sync is implied).
    static func fraction(for id: String) -> Double {
        sharedFraction(for: id)
    }

    static func setFraction(_ value: Double, for id: String) {
        setSharedFraction(value, for: id)
    }

    /// Registers the live editor scroll view for immediate preview→editor sync (split). Clear on `dismantleNSView`.
    static func setPreviewToEditorScrollHandler(for id: String, _ handler: ((Double) -> Void)?) {
        if let handler {
            previewToEditorScrollHandlers[id] = handler
        } else {
            previewToEditorScrollHandlers.removeValue(forKey: id)
        }
    }

    static func callPreviewToEditorScrollHandlerIfRegistered(for id: String, fraction: Double) -> Bool {
        guard let handler = previewToEditorScrollHandlers[id] else { return false }
        handler(fraction)
        return true
    }
}
