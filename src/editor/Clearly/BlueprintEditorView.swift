import AppKit
import SwiftUI

/// Global scratch strip (not saved in the markdown file). Plain text, same font as the editor.
struct BlueprintEditorView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isRichText = false
        textView.font = Theme.editorFont(ofSize: fontSize)
        textView.textColor = Theme.textColor
        textView.backgroundColor = Theme.backgroundColor
        textView.textContainerInset = NSSize(width: Theme.editorInsetX, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.binding = $text
        textView.font = Theme.editorFont(ofSize: fontSize)
        textView.textColor = Theme.textColor
        textView.backgroundColor = Theme.backgroundColor
        // Always push binding → view when the string differs (e.g. MASTER file load / reload). Do not gate on
        // isProgrammaticUpdate here — that could block external updates and leave the field stuck empty.
        if textView.string != text {
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            context.coordinator.isProgrammaticUpdate = false
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var binding: Binding<String>
        weak var textView: NSTextView?
        var isProgrammaticUpdate = false

        init(binding: Binding<String>) {
            self.binding = binding
        }


        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if !isProgrammaticUpdate {
                binding.wrappedValue = tv.string
            }
        }
    }
}
