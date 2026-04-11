import Combine
import Foundation

/// Bidirectional scroll hints between `EditorView` and `PreviewView` in split mode.
final class ScrollSyncRelay: ObservableObject {
    private var editorLead: Double?
    private var previewLead: Double?
    private let lock = NSLock()

    func ingestPreviewFractionForEditor(_ f: Double) {
        let v = min(1, max(0, f))
        lock.lock()
        editorLead = v
        lock.unlock()
        relayNotifyChanged()
    }

    func takeEditorLead() -> Double? {
        lock.lock()
        defer { lock.unlock() }
        let v = editorLead
        editorLead = nil
        return v
    }

    func proposePreviewScroll(_ f: Double) {
        let v = min(1, max(0, f))
        lock.lock()
        previewLead = v
        lock.unlock()
        relayNotifyChanged()
    }

    private func relayNotifyChanged() {
        if Thread.isMainThread {
            objectWillChange.send()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    func takePreviewLead() -> Double? {
        lock.lock()
        defer { lock.unlock() }
        let v = previewLead
        previewLead = nil
        return v
    }
}

extension ScrollBridge {
    private static var relays: [String: ScrollSyncRelay] = [:]

    static func registerRelay(_ relay: ScrollSyncRelay, for documentID: String) {
        relays[documentID] = relay
    }

    static func unregisterRelay(for documentID: String) {
        relays[documentID] = nil
    }

    /// Linked scroll: preview-originated updates the bridge + editor relay; align re-links at top; notifications use `ScrollFractionSource`.
    static func publishSharedFraction(_ value: Double, for id: String, source: ScrollFractionSource) {
        let v = min(1, max(0, value))
        switch source {
        case .preview:
            setSharedFraction(v, for: id, notify: nil)
            if !ScrollBridge.callPreviewToEditorScrollHandlerIfRegistered(for: id, fraction: v) {
                relays[id]?.ingestPreviewFractionForEditor(v)
            }
        case .align:
            setSharedFraction(v, for: id, notify: .align)
        case .editor:
            setSharedFraction(v, for: id, notify: .editor)
        }
    }
}
