import SwiftUI
import AppKit
import Combine
import os

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 12
    var fileURL: URL?
    var mode: ViewMode
    var positionSyncID: String
    @ObservedObject var scrollRelay: ScrollSyncRelay
    var findState: FindState?
    var outlineState: OutlineState?
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        DiagnosticLog.log("makeNSView: creating EditorView (\(text.count) chars)")
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let textView = ClearlyTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        TextCheckingPreferences.apply(to: textView)

        // Font
        textView.font = Theme.editorFont
        textView.textColor = Theme.textColor
        textView.backgroundColor = Theme.backgroundColor

        // Paragraph style with line height — use min/max line height + baselineOffset
        // so text is vertically centered in each line (not top-aligned like lineSpacing)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = Theme.editorLineHeight
        paragraph.maximumLineHeight = Theme.editorLineHeight
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [
            .font: Theme.editorFont,
            .foregroundColor: Theme.textColor,
            .paragraphStyle: paragraph,
            .baselineOffset: Theme.editorBaselineOffset
        ]

        // Insets
        textView.textContainerInset = NSSize(width: Theme.editorInsetX, height: Theme.editorInsetTop)
        textView.textContainer?.lineFragmentPadding = 0

        // Layout
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.allowsNonContiguousLayout = false

        // Insertion point color
        textView.insertionPointColor = Theme.textColor
        textView.documentURL = fileURL

        // Set initial text BEFORE attaching the text view delegate.
        // This avoids triggering textDidChange during makeNSView —
        // the first updateNSView call handles initial highlighting via the color-scheme check.
        // Note: we do NOT set textStorage.delegate — highlighting is driven explicitly
        // from textDidChange and updateNSView to avoid re-entrant layout manager access.
        let highlighter = MarkdownSyntaxHighlighter()
        context.coordinator.highlighter = highlighter
        textView.string = text
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.findState = findState
        context.coordinator.outlineState = outlineState
        if let findState {
            context.coordinator.observeFindState(findState)
        }
        // Wire up find bar presentation
        textView.onShowFind = { [weak findState] in
            guard let findState else { return }
            DispatchQueue.main.async {
                findState.present()
            }
        }

        // Wire up find navigation
        let coordinator = context.coordinator
        findState?.editorNavigateToNext = { [weak coordinator] in
            coordinator?.navigateToNextMatch()
        }
        findState?.editorNavigateToPrevious = { [weak coordinator] in
            coordinator?.navigateToPreviousMatch()
        }

        // Wire up outline scroll-to
        outlineState?.scrollToRange = { [weak coordinator] range in
            coordinator?.scrollToHeading(range)
        }

        // Observe scroll position for sync
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        context.coordinator.scrollViewRef = scrollView
        let syncID = context.coordinator.parent.positionSyncID
        ScrollBridge.setPreviewToEditorScrollHandler(for: syncID) { [weak coordinator = context.coordinator] fraction in
            guard let coordinator else { return }
            guard coordinator.parent.mode == .split else { return }
            guard let scrollView = coordinator.scrollViewRef else { return }
            coordinator.applyProgrammaticScroll(scrollView, fraction: fraction)
        }

        DiagnosticLog.log("makeNSView: EditorView ready")
        return scrollView
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        ScrollBridge.setPreviewToEditorScrollHandler(for: coordinator.parent.positionSyncID, nil)
        coordinator.scrollViewRef = nil
        NotificationCenter.default.removeObserver(coordinator)
        DiagnosticLog.log("dismantleNSView: EditorView torn down")
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ClearlyTextView else { return }

        // Keep coordinator's parent fresh so the binding never goes stale
        context.coordinator.parent = self

        let priorLast = context.coordinator.lastMode

        // Leaving edit mode: capture line-based position for later restore.
        if priorLast == .edit, (mode == .preview || mode == .split) {
            if let pos = context.coordinator.captureFirstVisibleLine() {
                ScrollPositionStore.save(pos, for: positionSyncID)
            }
        }

        // Entering edit mode from preview: restore line-based position.
        if (mode == .edit || mode == .split), priorLast == .preview {
            findState?.activeMode = .edit
            DispatchQueue.main.async { [weak coordinator = context.coordinator] in
                guard let coordinator else { return }
                if let pos = ScrollPositionStore.restore(for: self.positionSyncID) {
                    coordinator.restoreToLine(pos)
                }
                if self.findState?.isVisible == true {
                    coordinator.performFind()
                }
            }
        }

        // Split mode: use ScrollBridge for live sync (fraction-based is fine here).
        // ZStack ↔ HSplit swap creates a new NSScrollView — restore shared fraction.
        if priorLast == nil && mode == .split {
            context.coordinator.applyProgrammaticScroll(scrollView, fraction: ScrollBridge.sharedFraction(for: positionSyncID))
        }

        context.coordinator.lastMode = mode

        context.coordinator.updateCount += 1
        let count = context.coordinator.updateCount
        if count <= 5 || count % 100 == 0 {
            DiagnosticLog.log("updateNSView #\(count)")
        }

        // Always refresh colors (handles appearance changes via @Environment colorScheme)
        textView.backgroundColor = Theme.backgroundColor
        textView.insertionPointColor = Theme.textColor
        textView.documentURL = fileURL

        // Re-highlight and update typing attributes when appearance or font size changes
        let currentScheme = colorScheme
        let currentFontSize = fontSize
        let appearanceChanged = context.coordinator.lastColorScheme != currentScheme || context.coordinator.lastFontSize != currentFontSize
        if appearanceChanged {
            if count <= 5 {
                DiagnosticLog.log("updateNSView #\(count): appearance changed (scheme=\(currentScheme), fontSize=\(currentFontSize))")
            }
            context.coordinator.lastColorScheme = currentScheme
            context.coordinator.lastFontSize = currentFontSize
            textView.font = Theme.editorFont

            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = Theme.editorLineHeight
            paragraph.maximumLineHeight = Theme.editorLineHeight
            textView.typingAttributes = [
                .font: Theme.editorFont,
                .foregroundColor: Theme.textColor,
                .paragraphStyle: paragraph,
                .baselineOffset: Theme.editorBaselineOffset
            ]

            // Suppress scroll handler during highlighting to prevent layout manager deadlock
            context.coordinator.isHighlightingInProgress = true
            if let storage = textView.textStorage {
                context.coordinator.highlighter?.highlightAll(storage, caller: "appearance")
            }
            context.coordinator.isHighlightingInProgress = false
            context.coordinator.restoreFindHighlightsIfNeeded()
        }

        // Only update text if it changed externally (not from user typing).
        // When the user types, textDidChange increments pendingBindingUpdates
        // synchronously, then the async block decrements it after updating the
        // binding. While updates are pending, the text view is authoritative —
        // any mismatch is just the binding lagging behind, not an external change.
        let textMismatch = textView.string != text
        if !context.coordinator.isUpdating && context.coordinator.pendingBindingUpdates == 0 && textMismatch {
            DiagnosticLog.log("updateNSView #\(count): external text change (\(text.count) chars)")
            context.coordinator.isUpdating = true
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.isHighlightingInProgress = true
            if let storage = textView.textStorage {
                context.coordinator.highlighter?.highlightAll(storage, caller: "externalText")
            }
            context.coordinator.isHighlightingInProgress = false
            context.coordinator.restoreFindHighlightsIfNeeded()
            context.coordinator.isUpdating = false
        } else if context.coordinator.isUpdating && count <= 5 {
            DiagnosticLog.log("updateNSView #\(count): skipped text check (isUpdating)")
        }

        if count <= 5 || count % 100 == 0 {
            DiagnosticLog.log("updateNSView #\(count) done")
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var isUpdating = false
        var isHighlightingInProgress = false
        var highlighter: MarkdownSyntaxHighlighter?
        weak var textView: NSTextView?
        var lastMode: ViewMode?
        var findState: FindState?
        var outlineState: OutlineState?
        var lastColorScheme: ColorScheme?
        var lastFontSize: CGFloat?
        var updateCount = 0
        private var lastScrollTime: TimeInterval = 0
        private var editGeneration: UInt = 0
        /// Tracks how many async binding updates are in-flight. While > 0,
        /// updateNSView must not replace the text view's content — the text
        /// view is authoritative and the binding will catch up.
        var pendingBindingUpdates = 0
        weak var scrollViewRef: NSScrollView?
        /// Skip writing scroll bridge / relay while applying preview-driven scroll.
        var isApplyingRemoteScroll = false
        /// Cross-runloop guard: `setBoundsOrigin` posts `boundsDidChangeNotification`
        /// synchronously, but the scroll handler dispatches `computeScrollFraction`
        /// asynchronously. A plain `defer { isApplyingRemoteScroll = false }` is already
        /// cleared by the time the async block runs. This counter stays > 0 until an
        /// async cleanup pops it, so the async compute actually observes it.
        var programmaticScrollDepth: Int = 0
        private var lastRelayedToPreview: Double = -1

        // Find state tracking
        var matchRanges: [NSRange] = []
        private var currentMatchIdx = 0 // 0-based internal index
        private var findCancellables = Set<AnyCancellable>()

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func applyProgrammaticScroll(_ scrollView: NSScrollView, fraction: Double) {
            // Use document-visible rect (not clipView.bounds alone): NSTextView + insets/contentInsets make
            // bounds.origin.y vs frame.height mismatch WebKit’s fraction and can clamp to ~1 at the real top.
            //
            // IMPORTANT: `setBoundsOrigin` posts `boundsDidChangeNotification` SYNCHRONOUSLY
            // from inside this call. `scrollViewDidScroll` dispatches `computeScrollFraction`
            // async on the main queue. By the time that async block runs, a simple
            // `isApplyingRemoteScroll` bool guarded by `defer { = false }` has already been
            // cleared — so the flag offers zero protection against the echo. The fix:
            //   1. Bump a DEPTH COUNTER that stays elevated across the runloop (decremented
            //      from an async block) so the async `computeScrollFraction` actually sees it.
            //   2. Set `suppressOutgoingScrollUntil` BEFORE `setBoundsOrigin`, not after,
            //      so even notifications queued during the synchronous bounds change see
            //      the fresh deadline when they eventually run.
            // Cross-runloop guard: bump a counter that stays elevated across the runloop so
            // async `computeScrollFraction` blocks queued from the synchronous bounds change
            // observe programmaticScrollDepth > 0 and skip echo handling.
            programmaticScrollDepth += 1
            isApplyingRemoteScroll = true
            defer {
                isApplyingRemoteScroll = false
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if self.programmaticScrollDepth > 0 {
                        self.programmaticScrollDepth -= 1
                    }
                }
            }
            let clamped = CGFloat(min(max(fraction, 0), 1))
            guard let doc = scrollView.documentView else { return }
            scrollView.layoutSubtreeIfNeeded()
            if let tv = doc as? NSTextView {
                tv.layoutSubtreeIfNeeded()
                if let tc = tv.textContainer {
                    tv.layoutManager?.ensureLayout(for: tc)
                }
            }
            let vis = scrollView.documentVisibleRect
            let docH = doc.bounds.height
            let vh = vis.height
            let maxScroll = max(CGFloat(1), docH - vh)
            let targetMinY = clamped * maxScroll
            scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: targetMinY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        func scrollToHeading(_ range: NSRange) {
            guard let textView else { return }
            textView.scrollRangeToVisible(range)
            textView.showFindIndicator(for: range)
        }

        // MARK: - Line-based scroll position (for mode-switch persistence)

        /// Capture the first visible line number when leaving edit mode.
        func captureFirstVisibleLine() -> ScrollPositionStore.Position? {
            guard let textView else { return nil }
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return nil }
            let glyphIndex = layoutManager.glyphIndex(for: textView.visibleRect.origin, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let prefix = (textView.string as NSString).substring(to: min(charIndex, textView.string.count))
            let lineNumber = prefix.components(separatedBy: "\n").count - 1
            return .init(firstVisibleLine: lineNumber, fractionalLine: 0)
        }

        /// Restore scroll to a specific line number when entering edit mode.
        func restoreToLine(_ position: ScrollPositionStore.Position) {
            guard let textView else { return }
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            let lines = textView.string.components(separatedBy: "\n")
            let targetLine = min(position.firstVisibleLine, max(0, lines.count - 1))
            let charIndex = lines.prefix(targetLine).reduce(0) { $0 + $1.count + 1 }
            let safeIndex = min(charIndex, max(0, textView.string.count - 1))
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: safeIndex, length: 0),
                actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            textView.scroll(NSPoint(x: 0, y: rect.origin.y))
        }

        func observeFindState(_ state: FindState) {
            findCancellables.removeAll()

            state.$query
                .removeDuplicates()
                .sink { [weak self] _ in
                    guard let self,
                          let findState = self.findState,
                          findState.isVisible,
                          (findState.activeMode == .edit || findState.activeMode == .split) else { return }
                    self.performFind()
                }
                .store(in: &findCancellables)

            state.$isVisible
                .removeDuplicates()
                .sink { [weak self] visible in
                    guard let self else { return }
                    if visible {
                        let am = self.findState?.activeMode
                        guard am == .edit || am == .split else { return }
                        self.performFind()
                    } else {
                        self.clearFindHighlights()
                    }
                }
                .store(in: &findCancellables)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Skip if we're the ones setting text programmatically (from updateNSView)
            if isUpdating {
                DiagnosticLog.log("textDidChange skipped (isUpdating)")
                return
            }

            DiagnosticLog.log("textDidChange (\(textView.string.count) chars)")

            // Block updateNSView from replacing text while binding update is pending.
            // Without this, SwiftUI can call updateNSView (e.g., from a layout pass
            // triggered by the text view growing) BEFORE the async binding update fires,
            // see a mismatch between the old binding and the new text, and overwrite
            // the text view with the stale binding value — causing the cursor to jump.
            pendingBindingUpdates += 1

            // Save scroll position before highlighting
            let scrollView = textView.enclosingScrollView
            let savedOrigin = scrollView?.contentView.bounds.origin

            // Highlight synchronously so colors appear on the same frame as the keystroke
            isHighlightingInProgress = true
            if let storage = textView.textStorage {
                highlighter?.highlightAll(storage, caller: "textDidChange")
            }
            isHighlightingInProgress = false

            // Restore scroll position that highlighting may have disturbed
            if let scrollView, let savedOrigin {
                scrollView.contentView.scroll(to: savedOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }

            // Re-apply find highlights after syntax highlighting
            restoreFindHighlightsIfNeeded()

            // Update SwiftUI binding asynchronously to prevent re-entrant updateNSView.
            // Use a generation counter to coalesce rapid updates.
            editGeneration += 1
            let gen = editGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingBindingUpdates -= 1
                guard gen == self.editGeneration else { return }
                guard let textView = self.textView else { return }
                self.parent.text = textView.string
            }
        }

        private var scrollSuppressCount = 0

        @objc func scrollViewDidScroll(_ notification: Notification) {
            // Suppress during highlighting to avoid scheduling unnecessary async blocks
            guard !isHighlightingInProgress else {
                scrollSuppressCount += 1
                if scrollSuppressCount == 1 || scrollSuppressCount % 100 == 0 {
                    DiagnosticLog.log("scrollViewDidScroll suppressed ×\(scrollSuppressCount)")
                }
                return
            }

            guard let clipView = notification.object as? NSClipView else { return }

            // Synchronous pre-filter: if we're inside a programmatic scroll (or inside
            // its cross-runloop cleanup window), don't even enqueue the async compute.
            // This eliminates the preview→editor echo at the source.
            if isApplyingRemoteScroll || programmaticScrollDepth > 0 { return }

            // Defer layout manager queries to the next run loop iteration.
            // boundsDidChangeNotification fires synchronously during layout passes;
            // querying the layout manager in that same call stack deadlocks the main thread.
            DispatchQueue.main.async { [weak self] in
                self?.computeScrollFraction(clipView)
            }
        }

        private func computeScrollFraction(_ clipView: NSClipView) {
            guard !isApplyingRemoteScroll else { return }
            guard programmaticScrollDepth == 0 else { return }
            // Full preview hides the editor; its NSScrollView still gets bounds/layout updates with unreliable
            // documentVisibleRect metrics. Writing those fractions would overwrite preview-driven ScrollBridge values.
            guard parent.mode == .edit || parent.mode == .split else { return }
            let now = CACurrentMediaTime()
            guard let scrollView = clipView.enclosingScrollView else { return }
            guard now - lastScrollTime >= 0.016 else { return }
            lastScrollTime = now

            guard let doc = scrollView.documentView else { return }
            scrollView.layoutSubtreeIfNeeded()
            if let tv = doc as? NSTextView {
                tv.layoutSubtreeIfNeeded()
                if let tc = tv.textContainer {
                    tv.layoutManager?.ensureLayout(for: tc)
                }
            }
            let vis = scrollView.documentVisibleRect
            let docH = doc.bounds.height
            let vh = vis.height
            let maxScroll = max(CGFloat(1), docH - vh)
            let raw = Double(vis.minY / maxScroll)
            let f = min(max(raw, 0), 1)

            // Never post `clearlySharedScrollFractionChanged` from here. In split, `ScrollSyncRelay.proposePreviewScroll`
            // is the sole editor→preview path; posting notify:.editor duplicated that and let bogus NSTextView ratios
            // drive WK `scrollTo`, which fed back as scrollSync ~1 and jumped the editor.
            ScrollBridge.setSharedFraction(f, for: parent.positionSyncID, notify: nil)
            if parent.mode == .split, abs(f - lastRelayedToPreview) > 1e-5 {
                lastRelayedToPreview = f
                parent.scrollRelay.proposePreviewScroll(f)
            }
        }

        // MARK: - Find

        func restoreFindHighlightsIfNeeded() {
            guard findState?.isVisible == true, !(findState?.query.isEmpty ?? true) else { return }
            // Re-apply cached highlight colors without re-running the full find
            // (which would scroll to the first match on every keystroke).
            guard !matchRanges.isEmpty else { return }
            applyFindHighlights()
        }

        func performFind() {
            guard let textView, let findState else { return }
            let query = findState.query
            clearFindHighlights()

            guard !query.isEmpty else {
                matchRanges = []
                currentMatchIdx = 0
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          let findState = self.findState,
                          findState.activeMode == .edit || findState.activeMode == .split else { return }
                    findState.matchCount = 0
                    findState.currentIndex = 0
                }
                return
            }

            // Find all matches (case-insensitive)
            let nsText = textView.string as NSString
            var ranges: [NSRange] = []
            var searchRange = NSRange(location: 0, length: nsText.length)
            while searchRange.location < nsText.length {
                let found = nsText.range(of: query, options: .caseInsensitive, range: searchRange)
                if found.location == NSNotFound { break }
                ranges.append(found)
                searchRange.location = found.upperBound
                searchRange.length = nsText.length - searchRange.location
            }

            matchRanges = ranges
            currentMatchIdx = ranges.isEmpty ? 0 : 0

            applyFindHighlights()

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let findState = self.findState,
                      findState.activeMode == .edit || findState.activeMode == .split else { return }
                findState.matchCount = ranges.count
                findState.currentIndex = ranges.isEmpty ? 0 : 1
            }

            if !ranges.isEmpty {
                textView.scrollRangeToVisible(ranges[0])
            }
        }

        func navigateToNextMatch() {
            guard !matchRanges.isEmpty else { return }
            currentMatchIdx = (currentMatchIdx + 1) % matchRanges.count
            applyFindHighlights()
            textView?.scrollRangeToVisible(matchRanges[currentMatchIdx])
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let findState = self.findState,
                      findState.activeMode == .edit || findState.activeMode == .split else { return }
                findState.currentIndex = self.currentMatchIdx + 1
            }
        }

        func navigateToPreviousMatch() {
            guard !matchRanges.isEmpty else { return }
            currentMatchIdx = (currentMatchIdx - 1 + matchRanges.count) % matchRanges.count
            applyFindHighlights()
            textView?.scrollRangeToVisible(matchRanges[currentMatchIdx])
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let findState = self.findState,
                      findState.activeMode == .edit || findState.activeMode == .split else { return }
                findState.currentIndex = self.currentMatchIdx + 1
            }
        }

        private func applyFindHighlights() {
            guard let textView, let storage = textView.textStorage else { return }

            // Clear existing find highlights first
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)

            // Apply highlight to all matches
            for (i, range) in matchRanges.enumerated() {
                guard range.upperBound <= storage.length else { continue }
                let color = (i == currentMatchIdx) ? Theme.findCurrentHighlightColor : Theme.findHighlightColor
                storage.addAttribute(.backgroundColor, value: color, range: range)
            }
            storage.endEditing()
        }

        func clearFindHighlights() {
            guard let textView, let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)
            storage.endEditing()
            matchRanges = []
            currentMatchIdx = 0
        }
    }
}
