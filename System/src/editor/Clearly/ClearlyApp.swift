import SwiftUI

func activateDocumentApp() {
    if NSApp.activationPolicy() != .regular {
        NSApp.setActivationPolicy(.regular)
    }
    // Document opens from the menu bar must steal focus from the current app.
    NSApp.activate(ignoringOtherApps: true)
}

// MARK: - App Delegate (dock icon management)

final class KindasMDEditorAppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [Any] = []
    private var commandQMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A normal Launch Services open activates the app and opens a document window.
        // Login-item launch stays inactive with no document windows, so collapse to
        // menubar-only only in that state instead of guessing from parent PID.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if !NSApp.isActive && !self.hasDocumentWindows() {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        // Watch multiple signals — window close, app deactivate, main window change
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.updateActivationPolicy() }
        })
        observers.append(nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.updateActivationPolicy() }
        })
        observers.append(nc.addObserver(forName: NSWindow.didResignMainNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.updateActivationPolicy() }
        })
        observers.append(nc.addObserver(forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main) { notification in
            guard let window = notification.object as? NSWindow else { return }
            // Only for document windows, not panels/sheets/scratchpads
            guard !(window is NSPanel), !window.isSheet, window.level != .floating else { return }
            guard window.frame.width >= 50 && window.frame.height >= 50 else { return }
            activateDocumentApp()
            window.orderFrontRegardless()
        })

        commandQMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.shouldCloseToMenuBar(for: event) else { return event }
            self.closeDocumentWindowsToMenuBar()
            return nil
        }

    }

    // MARK: - Spelling and Grammar menu injection

    /// SwiftUI owns the Edit menu and regenerates its items on every update cycle.
    /// `applicationWillUpdate` fires on every run-loop iteration just before the
    /// UI refreshes, so we can re-inject our submenu after SwiftUI wipes it.
    /// The guard on `contains(where:)` makes this a no-op in the common case.
    func applicationWillUpdate(_ notification: Notification) {
        injectSpellingMenuIfNeeded()
    }

    private func injectSpellingMenuIfNeeded() {
        guard let editMenu = NSApp.mainMenu?.item(withTitle: "Edit")?.submenu else { return }
        guard !editMenu.items.contains(where: { $0.title == "Spelling and Grammar" }) else { return }

        let spellingItem = NSMenuItem(title: "Spelling and Grammar", action: nil, keyEquivalent: "")
        let spellingMenu = NSMenu(title: "Spelling and Grammar")

        let showItem = NSMenuItem(title: "Show Spelling and Grammar", action: #selector(NSText.showGuessPanel(_:)), keyEquivalent: ":")
        showItem.keyEquivalentModifierMask = [.command]
        spellingMenu.addItem(showItem)

        let checkItem = NSMenuItem(title: "Check Document Now", action: #selector(NSText.checkSpelling(_:)), keyEquivalent: ";")
        checkItem.keyEquivalentModifierMask = [.command]
        spellingMenu.addItem(checkItem)

        spellingMenu.addItem(.separator())
        spellingMenu.addItem(NSMenuItem(title: "Check Spelling While Typing", action: #selector(NSTextView.toggleContinuousSpellChecking(_:)), keyEquivalent: ""))
        spellingMenu.addItem(NSMenuItem(title: "Check Grammar With Spelling", action: #selector(NSTextView.toggleGrammarChecking(_:)), keyEquivalent: ""))
        spellingMenu.addItem(NSMenuItem(title: "Correct Spelling Automatically", action: #selector(NSTextView.toggleAutomaticSpellingCorrection(_:)), keyEquivalent: ""))

        spellingItem.submenu = spellingMenu

        // Place before Writing Tools (and its preceding separator) if present.
        if let writingToolsIndex = editMenu.items.firstIndex(where: { $0.title == "Writing Tools" }) {
            // Insert before the separator that precedes Writing Tools
            let insertIndex = (writingToolsIndex > 0 && editMenu.items[writingToolsIndex - 1].isSeparatorItem)
                ? writingToolsIndex - 1
                : writingToolsIndex
            editMenu.insertItem(spellingItem, at: insertIndex)
            editMenu.insertItem(.separator(), at: insertIndex)
        } else {
            editMenu.addItem(.separator())
            editMenu.addItem(spellingItem)
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        if hasDocumentWindows() && NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func closeDocumentWindowsToMenuBar() {
        let documentWindows = NSApp.windows.filter { window in
            guard window.isVisible || window.isMiniaturized else { return false }
            if window.level == .floating { return false }
            if window.isSheet { return false }
            if window is NSPanel { return false }
            if window.frame.width < 50 || window.frame.height < 50 { return false }
            return true
        }

        for window in documentWindows {
            window.performClose(nil)
        }

        Task { @MainActor in ScratchpadManager.shared.closeAll() }
        updateActivationPolicy()
    }

    private func updateActivationPolicy() {
        if hasDocumentWindows() {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        } else {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    /// A "document window" is any user-facing window that isn't a scratchpad,
    /// MenuBarExtra panel, sheet, or internal SwiftUI bookkeeping window.
    private func hasDocumentWindows() -> Bool {
        NSApp.windows.contains { window in
            guard window.isVisible || window.isMiniaturized else { return false }
            if window.level == .floating { return false }
            if window.isSheet { return false }
            if window is NSPanel { return false }
            if window.frame.width < 50 || window.frame.height < 50 { return false }
            return true
        }
    }

    func shouldCloseToMenuBar(for event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        guard event.charactersIgnoringModifiers?.lowercased() == "q" else { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifiers == [.command]
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let commandQMonitor {
            NSEvent.removeMonitor(commandQMonitor)
            self.commandQMonitor = nil
        }
    }
}

@main
struct KindasMDEditorApp: App {
    @NSApplicationDelegateAdaptor(KindasMDEditorAppDelegate.self) var appDelegate
    @AppStorage("themePreference") private var themePreference = "system"
    private let recentMenuHelper = RecentMenuHelper()
    @State private var scratchpadManager = ScratchpadManager.shared

    init() {
        Self.migrateFontSizeIfNeeded()
        BundledFontRegistration.registerBundledFonts()
        DiagnosticLog.trimIfNeeded()
        DiagnosticLog.log("App launched")
    }

    /// Migrate old 16pt font size to new 12pt default. Removes stored value if it was 16.0.
    private static func migrateFontSizeIfNeeded() {
        let d = UserDefaults.standard
        let key = "editorFontSize"
        guard d.object(forKey: key) != nil else { return }
        let stored = d.double(forKey: key)
        if stored == 16.0 {
            d.removeObject(forKey: key) // Lets the new default (12) take effect
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch themePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .preferredColorScheme(resolvedColorScheme)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 720, height: 900)
        .commands {
            CommandGroup(after: .importExport) {
                ExportPDFCommand()
            }
            CommandGroup(replacing: .printItem) {
                PrintCommand()
            }
            CommandGroup(after: .textEditing) {
                FindCommand()
                BlueprintToggleCommand()
                MasterStripToggleCommand()
                OutlineToggleCommand()
                ViewModeCommands()
            }
            CommandGroup(after: .textFormatting) {
                FontSizeCommands()
            }
            CommandGroup(replacing: .help) {
                Button("KindasMD Help") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/Shpigford/clearly/issues")!)
                }
                Divider()
                Button("Export Diagnostic Log…") {
                    do {
                        let logText = try DiagnosticLog.exportRecentLogs()
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.plainText]
                        panel.nameFieldStringValue = "KindasMD-Diagnostic-Log.txt"
                        guard panel.runModal() == .OK, let url = panel.url else { return }
                        try logText.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        let alert = NSAlert(error: error)
                        alert.runModal()
                    }
                }
            }
            CommandMenu("Format") {
                Button("Bold") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleBold(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleItalic(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Strikethrough") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleStrikethrough(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])

                Button("Heading") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertHeading(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Divider()

                Button("Link...") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertLink(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Image...") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertImage(_:)), to: nil, from: nil)
                }

                Divider()

                Button("Bullet List") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleBulletList(_:)), to: nil, from: nil)
                }

                Button("Numbered List") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleNumberedList(_:)), to: nil, from: nil)
                }

                Button("Todo") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleTodoList(_:)), to: nil, from: nil)
                }

                Divider()

                Button("Quote") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleBlockquote(_:)), to: nil, from: nil)
                }

                Button("Horizontal Rule") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertHorizontalRule(_:)), to: nil, from: nil)
                }

                Button("Table") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertMarkdownTable(_:)), to: nil, from: nil)
                }

                Divider()

                Button("Code") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleInlineCode(_:)), to: nil, from: nil)
                }

                Button("Code Block") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertCodeBlock(_:)), to: nil, from: nil)
                }

                Divider()

                Button("Math") {
                    NSApp.sendAction(#selector(ClearlyTextView.toggleInlineMath(_:)), to: nil, from: nil)
                }

                Button("Math Block") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertMathBlock(_:)), to: nil, from: nil)
                }

                Divider()

                Button("Page Break") {
                    NSApp.sendAction(#selector(ClearlyTextView.insertPageBreak(_:)), to: nil, from: nil)
                }
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(resolvedColorScheme)
        }

        MenuBarExtra("Scratchpads", image: "ScratchpadMenuBarIcon") {
            ScratchpadMenuBar(manager: scratchpadManager)
        }
    }
}

struct FindCommand: View {
    @FocusedValue(\.findState) var findState

    var body: some View {
        Button("Find…") {
            findState?.present()
        }
        .keyboardShortcut("f", modifiers: .command)
    }
}

struct BlueprintToggleCommand: View {
    var body: some View {
        Button("Toggle Characters Strip") {
            NotificationCenter.default.post(name: .clearlyToggleBlueprint, object: nil)
        }
        .keyboardShortcut("b", modifiers: [.command, .option])
    }
}

struct MasterStripToggleCommand: View {
    var body: some View {
        Button("Toggle MASTER Strip") {
            NotificationCenter.default.post(name: .clearlyToggleMasterStrip, object: nil)
        }
        .keyboardShortcut("m", modifiers: [.command, .option])
    }
}

struct OutlineToggleCommand: View {
    @FocusedValue(\.outlineState) var outlineState

    var body: some View {
        Button("Toggle Outline") {
            outlineState?.toggle()
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])
    }
}

struct ViewModeCommands: View {
    @FocusedValue(\.viewMode) var mode

    var body: some View {
        Button("Editor") {
            mode?.wrappedValue = .edit
        }
        .keyboardShortcut("1", modifiers: .command)

        Button("Split View") {
            mode?.wrappedValue = .split
        }
        .keyboardShortcut("3", modifiers: .command)

        Button("Preview") {
            mode?.wrappedValue = .preview
        }
        .keyboardShortcut("2", modifiers: .command)
    }
}

// MARK: - Font Size Commands

struct FontSizeCommands: View {
    @AppStorage("editorFontSize") private var fontSize: Double = 12

    var body: some View {
        Button("Increase Font Size") {
            fontSize = min(fontSize + 1, 24)
        }
        .keyboardShortcut("+", modifiers: .command)

        Button("Decrease Font Size") {
            fontSize = max(fontSize - 1, 12)
        }
        .keyboardShortcut("-", modifiers: .command)
    }
}

// MARK: - Export / Print Commands

struct ExportPDFCommand: View {
    @FocusedValue(\.documentText) var text
    @FocusedValue(\.documentFileURL) var fileURL
    @AppStorage("editorFontSize") private var fontSize: Double = 12

    var body: some View {
        Button("Export as PDF…") {
            guard let text else { return }
            PDFExporter().exportPDF(markdown: text, fontSize: CGFloat(fontSize), fileURL: fileURL)
        }
        .disabled(text == nil)
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }
}

struct PrintCommand: View {
    @FocusedValue(\.documentText) var text
    @FocusedValue(\.documentFileURL) var fileURL
    @AppStorage("editorFontSize") private var fontSize: Double = 12

    var body: some View {
        Button("Print…") {
            guard let text else { return }
            PDFExporter().printHTML(markdown: text, fontSize: CGFloat(fontSize), fileURL: fileURL)
        }
        .disabled(text == nil)
        .keyboardShortcut("p", modifiers: .command)
    }
}

