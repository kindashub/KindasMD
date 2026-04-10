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

// MARK: - Prove which binary is running (Dock vs stray Xcode instance)

/// Sets `NSWindow.subtitle` so you can see build + whether this is the MBP-Mods install or a DerivedData run.
struct WindowKindasBuildSubtitle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let bundlePath = Bundle.main.bundlePath
        let origin: String = {
            if bundlePath.contains("/MBP-Mods/KindasMD/KindasMDEditor.app") {
                return "MBP-Mods install"
            }
            if bundlePath.contains("DerivedData") {
                return "⚠️ DerivedData — quit this; use Dock + KindasMD/KindasMDEditor.app"
            }
            return (bundlePath as NSString).lastPathComponent
        }()
        DispatchQueue.main.async {
            nsView.window?.subtitle = "KindasMD build \(ver) · \(origin)"
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
        // Always start in Edit mode with all toggles off (clean state per document)
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
            .background(WindowKindasBuildSubtitle())
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
            .toolbar { toolbarContent }
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

    @ViewBuilder
    private var mainContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
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
                TextEditBrowserView(model: textEditBrowser)
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Mode", selection: $mode) {
                Image(systemName: "pencil")
                    .tag(ViewMode.edit)
                Image(systemName: "rectangle.split.2x1")
                    .tag(ViewMode.split)
                Image(systemName: "eye")
                    .tag(ViewMode.preview)
            }
            .pickerStyle(.segmented)
            .frame(width: 152)
            .help("Editor / Split / Preview (⌘1 / ⌘3 / ⌘2)")
        }
        ToolbarItem(placement: .automatic) {
            QuickCopyButtonsView()
        }
        ToolbarItem(placement: .automatic) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    boxStripVisible.toggle()
                }
            } label: {
                Label("Characters", systemImage: "square.grid.3x3")
                    .symbolVariant(boxStripVisible ? .fill : .none)
                    .foregroundStyle(boxStripVisible ? Color.accentColor : .secondary)
            }
            .help("Toggle box character palette (⌘⌥B)")
        }
        ToolbarItem(placement: .automatic) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    masterStripVisible.toggle()
                }
            } label: {
                Label("MASTER", systemImage: "doc.text")
                    .symbolVariant(masterStripVisible ? .fill : .none)
                    .foregroundStyle(masterStripVisible ? Color.accentColor : .secondary)
            }
            .help("Toggle MASTER notes strip (⌘⌥M)")
        }
        ToolbarItem(placement: .automatic) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    // Toggle TextEdit browser (mutually exclusive with outline)
                    showTextEditBrowser.toggle()
                }
            } label: {
                Image(systemName: "folder")
                    .symbolVariant(showTextEditBrowser ? .fill : .none)
                    .foregroundStyle(showTextEditBrowser ? Color.accentColor : .secondary)
            }
            .help("TextMD File Browser")
        }
        ToolbarItem(placement: .automatic) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    outlineState.toggle()
                }
            } label: {
                Image(systemName: "list.bullet.indent")
                    .symbolVariant(outlineState.isVisible ? .fill : .none)
                    .foregroundStyle(outlineState.isVisible ? Color.accentColor : .secondary)
            }
            .help("Document Outline (Shift+Cmd+O)")
        }
        ToolbarItem(placement: .automatic) {
            Button {
                findState.present()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Find (Cmd+F)")
        }
    }

    private func loadBoxCells() {
        let cellData = UserDefaults.standard.data(forKey: "kindasBoxGridCells_v2")
        guard let d = cellData else { return }
        guard let decoded = try? JSONDecoder().decode([String].self, from: d) else { return }
        guard decoded.count == KindasBoxGridConfig.cellCount else { return }
        boxCells = decoded
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

