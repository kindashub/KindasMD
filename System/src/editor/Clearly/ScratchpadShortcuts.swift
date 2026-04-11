import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let newScratchpad = Self("newScratchpad", default: .init(.n, modifiers: [.control, .option, .command]))
}

extension View {
    /// Applies the default new scratchpad keyboard shortcut (⌃⌥⌘N).
    /// Note: The actual shortcut handling is done via KeyboardShortcuts; this is for UI display only.
    @ViewBuilder
    func newScratchpadKeyboardShortcut() -> some View {
        self.keyboardShortcut("n", modifiers: [.control, .option, .command])
    }
}
