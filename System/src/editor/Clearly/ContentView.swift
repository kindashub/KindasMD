import Combine
import SwiftUI

enum ViewMode: String, CaseIterable {
    case edit
    case split
    case preview
}

struct ViewModeKey: FocusedValueKey {
    typealias Value = Binding<ViewMode>
}

struct DocumentTextKey: FocusedValueKey {
    typealias Value = String
}

struct DocumentFileURLKey: FocusedValueKey {
    typealias Value = URL
}

struct FindStateKey: FocusedValueKey {
    typealias Value = FindState
}

struct OutlineStateKey: FocusedValueKey {
    typealias Value = OutlineState
}

extension FocusedValues {
    var viewMode: Binding<ViewMode>? {
        get { self[ViewModeKey.self] }
        set { self[ViewModeKey.self] = newValue }
    }
    var documentText: String? {
        get { self[DocumentTextKey.self] }
        set { self[DocumentTextKey.self] = newValue }
    }
    var documentFileURL: URL? {
        get { self[DocumentFileURLKey.self] }
        set { self[DocumentFileURLKey.self] = newValue }
    }
    var findState: FindState? {
        get { self[FindStateKey.self] }
        set { self[FindStateKey.self] = newValue }
    }
    var outlineState: OutlineState? {
        get { self[OutlineStateKey.self] }
        set { self[OutlineStateKey.self] = newValue }
    }
}

// MARK: - Window Frame Persistence

/// Sets NSWindow.frameAutosaveName so macOS automatically saves/restores window size and position.
/// Uses a per-file autosave name so each document remembers its own window frame.
struct WindowFrameSaver: NSViewRepresentable {
    let fileURL: URL?

    final class Coordinator {
        var autosaveName: String?
    }

    private var autosaveName: String {
        fileURL?.absoluteString ?? "ClearlyUntitledWindow"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func applyAutosaveName(
        to window: NSWindow,
        coordinator: Coordinator,
        persistCurrentFrame: Bool
    ) {
        guard coordinator.autosaveName != autosaveName else { return }
        coordinator.autosaveName = autosaveName
        window.setFrameAutosaveName(autosaveName)
        if persistCurrentFrame {
            window.saveFrame(usingName: autosaveName)
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                applyAutosaveName(
                    to: window,
                    coordinator: context.coordinator,
                    persistCurrentFrame: false
                )
                // Ensure the document window comes to front after opening.
                activateDocumentApp()
                window.makeKeyAndOrderFront(nil)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        applyAutosaveName(
            to: window,
            coordinator: context.coordinator,
            persistCurrentFrame: context.coordinator.autosaveName != nil
        )
    }
}

struct HiddenToolbarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            content
        }
    }
}

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @State private var mode: ViewMode
    @State private var positionSyncID = UUID().uuidString
    @AppStorage("editorFontSize") private var fontSize: Double = 12
    /// Box character palette (⌘⌥B / toolbar). Separate from MASTER strip.
    @State private var boxStripVisible = false
    /// MASTER file picker + scratch editor (⌘⌥M / toolbar). Box strip stays at top; MASTER sits at bottom of column.
    @State private var masterStripVisible = false
    @State private var boxCells: [String] = KindasBoxGridConfig.defaultCells()
    @StateObject private var masterFolder = MasterFolderModel()
    @StateObject private var findState = FindState()
    @StateObject private var fileWatcher = FileWatcher()
    @StateObject private var outlineState = OutlineState()
    @StateObject private var textEditBrowser = TextEditBrowserModel()
    @StateObject private var scrollRelay = ScrollSyncRelay()
    @State private var showTextEditBrowser = false

    init(document: Binding<MarkdownDocument>, fileURL: URL? = nil) {
        self._document = document
        self.fileURL = fileURL
        // Always start in Edit mode for a clean slate on every document
        self._mode = State(initialValue: .edit)
        DiagnosticLog.log("Document opened: \(fileURL?.lastPathComponent ?? "untitled")")
    }

    private var wordCount: Int {
        document.text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var characterCount: Int {
        document.text.count
    }

    var body: some View {
        contentWithEventHandlers
    }

    private var contentWithModifiers: some View {
        mainContent
            .frame(minWidth: 500, minHeight: 400)
            .background(Theme.backgroundColorSwiftUI)
            .modifier(HiddenToolbarBackground())
            .background(WindowFrameSaver(fileURL: fileURL))
            .animation(.easeInOut(duration: 0.15), value: mode)
            .animation(.easeInOut(duration: 0.2), value: boxStripVisible)
            .animation(.easeInOut(duration: 0.2), value: masterStripVisible)
    }

    private var contentWithEventHandlers: some View {
        contentWithModifiers
            .onChange(of: outlineState.isVisible) { _, newValue in
                // Mutual exclusion: when outline shows, hide textEdit browser
                if newValue {
                    showTextEditBrowser = false
                }
            }
            .onChange(of: showTextEditBrowser) { _, newValue in
                // Mutual exclusion: when textEdit browser shows, hide outline
                if newValue {
                    outlineState.isVisible = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearlyToggleBlueprint), perform: toggleBlueprint)
            .onReceive(NotificationCenter.default.publisher(for: .clearlyToggleMasterStrip), perform: toggleMasterStrip)
            .focusedSceneValue(\.viewMode, $mode)
            .focusedSceneValue(\.documentText, document.text)
            .focusedSceneValue(\.documentFileURL, fileURL)
            .focusedSceneValue(\.findState, findState)
            .focusedSceneValue(\.outlineState, outlineState)
            .onAppear(perform: onAppearHandler)
            .onDisappear(perform: onDisappearHandler)
            .onChange(of: boxCells, perform: saveBoxCells)
            .onChange(of: fileURL) { _, newURL in
                fileWatcher.watch(newURL, currentText: document.text)
            }
            .onChange(of: document.text, perform: handleDocumentTextChange)
            .onChange(of: masterStripVisible, perform: handleMasterStripVisibilityChange)
    }

    // MARK: - Custom Control Bar (replaces native toolbar)

    private var controlBarContent: some View {
        HStack(spacing: 6) {
            // Filename display on the left
            Text(fileURL?.lastPathComponent ?? "Untitled")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 200, alignment: .leading)

            Spacer()

            // Quick Copy buttons
            QuickCopyButtonsView()

            Divider().frame(height: 16)

            // Mode buttons -- flat, plain, small (replaces segmented Picker)
            controlBarButton("pencil", active: mode == .edit) { mode = .edit }
            controlBarButton("rectangle.split.2x1", active: mode == .split) { mode = .split }
            controlBarButton("eye", active: mode == .preview) { mode = .preview }

            Divider().frame(height: 16)

            // Toggle buttons -- flat, plain, small
            controlBarButton("square.grid.3x3", active: boxStripVisible) {
                withAnimation(.easeInOut(duration: 0.2)) { boxStripVisible.toggle() }
            }
            controlBarButton("doc.text", active: masterStripVisible) {
                withAnimation(.easeInOut(duration: 0.2)) { masterStripVisible.toggle() }
            }
            controlBarButton("folder", active: showTextEditBrowser) {
                withAnimation(.easeInOut(duration: 0.2)) { showTextEditBrowser.toggle() }
            }
            controlBarButton("list.bullet.indent", active: outlineState.isVisible) {
                withAnimation(.easeInOut(duration: 0.2)) { outlineState.toggle() }
            }
            controlBarButton("magnifyingglass", active: findState.isVisible) {
                findState.present()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.backgroundColorSwiftUI)
    }

    private func controlBarButton(_ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(active ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 22, height: 20)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var mainContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                controlBarContent
                Divider()
                if findState.isVisible {
                    FindBarView(findState: findState)
                    Divider()
                }
                // Characters strip at top; MASTER at bottom (Edit / Split / Preview) so MASTER stays usable while reading preview.
                if boxStripVisible {
                    KindasCharactersStripView(boxCells: $boxCells, fontSize: CGFloat(fontSize))
                    Divider()
                }
                // Same ruler row in edit, split, and preview so switching modes does not jump the layout.
                ColumnRulerView(fontSize: CGFloat(fontSize))
                    .frame(height: 24)
                mainEditorContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // MASTER lives in bottom safe-area inset (above stats) so it is anchored to the window bottom, not the flex editor.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomSafeAreaContent
            }

            if outlineState.isVisible {
                Divider()
                OutlineView(outlineState: outlineState)
            } else if showTextEditBrowser {
                Divider()
                TextEditBrowserView(model: textEditBrowser, onFileSelected: { url in
                    ReadOnlyViewer.open(fileURL: url)
                })
            }
        }
    }

    @ViewBuilder
    private var bottomSafeAreaContent: some View {
        VStack(spacing: 0) {
            if masterStripVisible {
                Divider()
                KindasMasterStripView(
                    masterModel: masterFolder,
                    fontSize: CGFloat(fontSize),
                    charactersVisible: boxStripVisible
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 12) {
                Text("\(wordCount) words")
                Text("\(characterCount) characters")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.backgroundColorSwiftUI)
        }
        .background(Theme.backgroundColorSwiftUI)
    }

    @ViewBuilder
    private var mainEditorContent: some View {
        Group {
            if mode == .split {
                // Side-by-side editor | preview (Clearly / NSSplitView). Default bias ~40% editor / ~60% preview.
                GeometryReader { geo in
                    let w = max(440, geo.size.width)
                    // ~40% default editor width. Avoid `.layoutPriority` on preview — it starves the editor.
                    let editorIdealWidth = max(260, w * 0.40)
                    HSplitView {
                        EditorView(text: $document.text, fontSize: CGFloat(fontSize), fileURL: fileURL, mode: mode, positionSyncID: positionSyncID, scrollRelay: scrollRelay, findState: findState, outlineState: outlineState)
                            .frame(minWidth: 220, idealWidth: editorIdealWidth, maxWidth: .infinity)
                        PreviewView(markdown: document.text, fontSize: CGFloat(fontSize), mode: mode, positionSyncID: positionSyncID, scrollRelay: scrollRelay, fileURL: fileURL, findState: findState, outlineState: outlineState)
                            .frame(minWidth: 220, maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    // Preview first so `updateNSView` tends to run before Editor on mode changes — WK snapshot can commit before editor restores scroll.
                    PreviewView(markdown: document.text, fontSize: CGFloat(fontSize), mode: mode, positionSyncID: positionSyncID, scrollRelay: scrollRelay, fileURL: fileURL, findState: findState, outlineState: outlineState)
                        .opacity(mode == .preview ? 1 : 0)
                        .allowsHitTesting(mode == .preview)
                    EditorView(text: $document.text, fontSize: CGFloat(fontSize), fileURL: fileURL, mode: mode, positionSyncID: positionSyncID, scrollRelay: scrollRelay, findState: findState, outlineState: outlineState)
                        .opacity(mode == .edit ? 1 : 0)
                        .allowsHitTesting(mode == .edit)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadBoxCells() {
        let cellData = UserDefaults.standard.data(forKey: "kindasBoxGridCells_v2")
        guard let d = cellData else {
            // No saved data, use defaults
            boxCells = KindasBoxGridConfig.defaultCells()
            return
        }
        guard let decoded = try? JSONDecoder().decode([String].self, from: d) else {
            boxCells = KindasBoxGridConfig.defaultCells()
            return
        }

        let expectedCount = KindasBoxGridConfig.cellCount  // 194
        let oldCount = KindasBoxGridConfig.columnsPerRow * 5  // 205 (old 5x41 format)

        if decoded.count == expectedCount {
            // Current format - use as-is
            boxCells = decoded
        } else if decoded.count == oldCount {
            // Migration: old 5x41 format (205 cells) -> new 6-row format (194 cells)
            // Keep first 164 cells (rows 1-4), add defaults for new rows 5-6
            var migrated = Array(decoded.prefix(KindasBoxGridConfig.columnsPerRow * 4))
            let defaults = KindasBoxGridConfig.defaultCells()
            // Append defaults for row 5 (20 cells) and row 6 (10 cells)
            let row5Start = KindasBoxGridConfig.columnsPerRow * 4
            migrated.append(contentsOf: defaults[row5Start..<expectedCount])
            boxCells = migrated
            // Save the migrated data
            saveBoxCells(migrated)
        } else {
            // Unexpected count, use defaults
            boxCells = KindasBoxGridConfig.defaultCells()
        }
    }

    private func setupFileWatcher() {
        fileWatcher.onChange = { [self] newText in
            document.text = newText
        }
        fileWatcher.watch(fileURL, currentText: document.text)
    }

    private func handleOnAppear() {
        masterFolder.ensureFolderAndRefresh()
        ScrollBridge.registerRelay(scrollRelay, for: positionSyncID)
        loadBoxCells()
        setupFileWatcher()
        outlineState.parseHeadings(from: document.text)
    }

    private func handleDocumentTextChange(_ newText: String) {
        fileWatcher.updateCurrentText(newText)
        outlineState.parseHeadings(from: newText)
    }

    private func saveBoxCells(_ newValue: [String]) {
        if let data = try? JSONEncoder().encode(newValue) {
            UserDefaults.standard.set(data, forKey: "kindasBoxGridCells_v2")
        }
    }

    private func handleMasterStripVisibilityChange(_ visible: Bool) {
        if visible {
            masterFolder.ensureFolderAndRefresh()
        }
    }

    private func toggleBlueprint(_: Notification) {
        withAnimation(.easeInOut(duration: 0.2)) {
            boxStripVisible.toggle()
        }
    }

    private func toggleMasterStrip(_: Notification) {
        withAnimation(.easeInOut(duration: 0.2)) {
            masterStripVisible.toggle()
        }
    }

    private func onAppearHandler() {
        handleOnAppear()
    }

    private func onDisappearHandler() {
        ScrollBridge.unregisterRelay(for: positionSyncID)
    }
}

