import AppKit
import Darwin
import SwiftUI

// MARK: - Box character grid (copy to clipboard; optional edit layout)

enum KindasBoxGridConfig {
    /// Full-width strip grid: 41 columns × 4 rows (see KindasMD_Blueprint.md — dense palette).
    static let columnsPerRow = 41
    static let rowCount = 4
    static var cellCount: Int { columnsPerRow * rowCount }

    static func defaultCells() -> [String] {
        let raw =
            "╌─═━╎│║┃█░▒▓⦿┌┐└┘├┤┬┴┼╔╗╚╝╠╣╦╩╬·•□■○●★☆§→←↑↓"
            + "╴╵╶╷╸╹╺╻╼╽╾╿┏┓┗┛┳┻╋┣┫╍╏═╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫"
            + "▀▄▌▐▖▗▘▝▞▟▁▂▃▄▅▆▇█░▒▓▔▕▖▗▘▙▚▛▜▝▞▟"
            + "⋯⋮⋯⌘⌥⇧⌃⌤␣¶†‡※‰♠♣♥♦✓✗⊢⊣⊤⊥⊦⊧⊨⊩⊪⊫⊬⊭⊮⊯"
            + "⇐⇒⇔∀∃∴∵⊂⊃⊆⊇∩∪∅∈∉∑∏∫√∞∧∨¬⊕⊗"
            + "αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖ"
        var cells = raw.map { String($0) }
        while cells.count < cellCount {
            cells.append(" ")
        }
        return Array(cells.prefix(cellCount))
    }

    /// Single extended grapheme per palette cell; empty input becomes a visible space.
    static func normalizeCell(_ s: String) -> String {
        let t = s.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        if t.isEmpty { return " " }
        guard let first = t.first else { return " " }
        return String(first)
    }
}

struct BoxCharacterPaletteView: View {
    @Binding var cells: [String]
    var fontSize: CGFloat

    private var columnsPerRow: Int { KindasBoxGridConfig.columnsPerRow }
    private var gridRows: Int { KindasBoxGridConfig.rowCount }

    var body: some View {
        let hPad: CGFloat = 9
        let spacing: CGFloat = 1

        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0 ..< gridRows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0 ..< columnsPerRow, id: \.self) { col in
                        let index = row * columnsPerRow + col
                        boxCell(character: safeCharacter(at: index))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, hPad)
    }

    private func safeCharacter(at index: Int) -> String {
        guard index < cells.count else { return " " }
        let v = cells[index]
        return v.isEmpty ? " " : v
    }

    @ViewBuilder
    private func boxCell(character: String) -> some View {
        let ch = character
        Button {
            copyToPasteboard(ch)
        } label: {
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: Theme.backgroundColor).opacity(0.55))
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.secondary.opacity(0.32), lineWidth: 0.5)
                    Text(ch.isEmpty ? " " : ch)
                        .font(.system(size: max(9, min(s * 0.58, fontSize * 0.72)), design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .minimumScaleFactor(0.35)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .help("Copy to clipboard")
    }

    private func copyToPasteboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
}

// MARK: - Edit grid (same geometry as palette; one character per cell)

struct BoxCharacterEditGridView: View {
    @Binding var cells: [String]
    var fontSize: CGFloat

    private var columnsPerRow: Int { KindasBoxGridConfig.columnsPerRow }
    private var gridRows: Int { KindasBoxGridConfig.rowCount }

    var body: some View {
        let hPad: CGFloat = 9
        let spacing: CGFloat = 1

        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0 ..< gridRows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0 ..< columnsPerRow, id: \.self) { col in
                        let index = row * columnsPerRow + col
                        editCell(at: index)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, hPad)
    }

    private func cellBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < cells.count else { return " " }
                let v = cells[index]
                return v.isEmpty ? " " : v
            },
            set: { newValue in
                var next = cells
                while next.count <= index {
                    next.append(" ")
                }
                next[index] = KindasBoxGridConfig.normalizeCell(newValue)
                cells = next
            }
        )
    }

    @ViewBuilder
    private func editCell(at index: Int) -> some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let fontSizePx = max(9, min(s * 0.58, fontSize * 0.72))
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: Theme.backgroundColor).opacity(0.55))
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.5)
                TextField("", text: cellBinding(at: index))
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSizePx, design: .monospaced))
                    .foregroundColor(Color.accentColor)
                    .tint(Color.accentColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .padding(2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .help("One character per square; paste is trimmed to one glyph")
    }
}

// MARK: - MASTER folder (default ~/TextMD/MASTER; optional security-scoped bookmark)

@MainActor
final class MasterFolderModel: ObservableObject {
    private static let bookmarkDefaultsKey = "kindasMasterFolderBookmark_v1"

    @Published var fileURLs: [URL] = []
    @Published var selectedURL: URL?
    @Published var text: String = ""
    /// Last disk error (read/save) for MASTER; shown in the strip so failures are not silent.
    @Published var lastIOError: String?
    /// Active root: default home-relative path, or a folder the user chose (stored as a security-scoped bookmark).
    @Published private(set) var masterRootURL: URL

    private var loadToken = UUID()
    private var saveTask: Task<Void, Never>?
    private var isApplyingLoad = false

    private var usesSecurityBookmark: Bool {
        UserDefaults.standard.data(forKey: Self.bookmarkDefaultsKey) != nil
    }

    init() {
        masterRootURL = Self.resolveMasterRootFromDefaults()
    }

    /// Real `~/…` — **not** the sandbox container (`…/Library/Containers/…/Data`), which would make `TextMD/MASTER` empty while Finder shows files under `/Users/you/…`.
    /// Prefer **`getpwuid` first**: GUI / document apps often set `HOME` to the container even when the app is not sandboxed; passwd is the stable real home on macOS.
    private static func resolvedUserHomeURL() -> URL {
        if let pw = getpwuid(getuid()) {
            let path = String(cString: pw.pointee.pw_dir)
            if path.hasPrefix("/"), !path.contains("/Library/Containers/") {
                return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
            }
        }
        if let home = ProcessInfo.processInfo.environment["HOME"],
           home.hasPrefix("/"),
           !home.contains("/Library/Containers/")
        {
            return URL(fileURLWithPath: home, isDirectory: true).standardizedFileURL
        }
        let fmHome = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        if fmHome.path.contains("/Library/Containers/") {
            DiagnosticLog.log("MasterFolder: homeDirectoryForCurrentUser is inside Containers — passwd/HOME did not yield a real home; MASTER path may be wrong")
        }
        return fmHome
    }

    private static func defaultMasterRoot() -> URL {
        resolvedUserHomeURL()
            .appendingPathComponent("TextMD/MASTER", isDirectory: true)
    }

    private static func resolveMasterRootFromDefaults() -> URL {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkDefaultsKey) else {
            return defaultMasterRoot()
        }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                UserDefaults.standard.removeObject(forKey: Self.bookmarkDefaultsKey)
                DiagnosticLog.log("MasterFolder: bookmark was stale — cleared; using default ~/TextMD/MASTER")
                return defaultMasterRoot()
            }
            return url.standardizedFileURL
        } catch {
            DiagnosticLog.log("MasterFolder: bookmark resolve failed: \(error)")
            UserDefaults.standard.removeObject(forKey: Self.bookmarkDefaultsKey)
            return defaultMasterRoot()
        }
    }

    func chooseMasterFolder() {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.canCreateDirectories = true
        p.allowsMultipleSelection = false
        p.directoryURL = masterRootURL
        p.prompt = "Choose MASTER folder"
        p.message = "Pick the folder that contains your master .md files (e.g. TextMD/MASTER)."
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: Self.bookmarkDefaultsKey)
            masterRootURL = url.standardizedFileURL
            DiagnosticLog.log("MasterFolder: saved security-scoped bookmark path=\(masterRootURL.path)")
            ensureFolderAndRefresh()
        } catch {
            DiagnosticLog.log("MasterFolder: bookmarkData failed: \(error)")
        }
    }

    func useDefaultMasterFolder() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkDefaultsKey)
        masterRootURL = Self.defaultMasterRoot()
        DiagnosticLog.log("MasterFolder: using default ~/TextMD/MASTER")
        ensureFolderAndRefresh()
    }

    func ensureFolderAndRefresh() {
        // Re-resolve default `~/TextMD/MASTER` every time so we never stick to a sandbox-container "home" path.
        if !usesSecurityBookmark {
            masterRootURL = Self.defaultMasterRoot()
            do {
                try FileManager.default.createDirectory(at: masterRootURL, withIntermediateDirectories: true)
            } catch {
                DiagnosticLog.log("MasterFolder: createDirectory failed: \(error)")
            }
        }
        refreshFileList(selectFirstIfNeeded: selectedURL == nil)
    }

    func refreshFileList(selectFirstIfNeeded: Bool) {
        let fm = FileManager.default
        let dir = masterRootURL
        let contents: [URL]

        let scoped = usesSecurityBookmark
        if scoped {
            guard dir.startAccessingSecurityScopedResource() else {
                DiagnosticLog.log("MasterFolder: startAccessingSecurityScopedResource failed path=\(dir.path)")
                fileURLs = []
                return
            }
        }
        defer {
            if scoped {
                dir.stopAccessingSecurityScopedResource()
            }
        }

        do {
            contents = try fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            DiagnosticLog.log("MasterFolder: contentsOfDirectory failed: \(error) path=\(dir.path)")
            fileURLs = []
            return
        }
        DiagnosticLog.log("MasterFolder: listing path=\(dir.path) entries=\(contents.count) bookmark=\(usesSecurityBookmark)")
        var mdFiles: [URL] = []
        for url in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            guard url.pathExtension.lowercased() == "md" else { continue }
            mdFiles.append(url.standardizedFileURL)
        }
        fileURLs = mdFiles.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
        DiagnosticLog.log("MasterFolder: \(fileURLs.count) .md file(s) — \(fileURLs.map(\.lastPathComponent).joined(separator: ", "))")
        if selectFirstIfNeeded, selectedURL == nil, let first = fileURLs.first {
            select(first)
        }
    }

    private func readFileData(at url: URL) -> Data {
        do {
            let data: Data
            if usesSecurityBookmark {
                guard masterRootURL.startAccessingSecurityScopedResource() else {
                    let msg = "Security-scoped access to the MASTER folder was denied."
                    lastIOError = msg
                    DiagnosticLog.log("MasterFolder: read — startAccessingSecurityScopedResource failed")
                    return Data()
                }
                defer { masterRootURL.stopAccessingSecurityScopedResource() }
                data = try Data(contentsOf: url)
            } else {
                data = try Data(contentsOf: url)
            }
            lastIOError = nil
            return data
        } catch {
            lastIOError = error.localizedDescription
            DiagnosticLog.log("MasterFolder: read failed: \(error) url=\(url.path)")
            return Data()
        }
    }

    private func writeFileData(_ data: Data, to url: URL) throws {
        do {
            if usesSecurityBookmark {
                guard masterRootURL.startAccessingSecurityScopedResource() else {
                    lastIOError = "Security-scoped access to the MASTER folder was denied."
                    throw CocoaError(.fileReadNoPermission)
                }
                defer { masterRootURL.stopAccessingSecurityScopedResource() }
                try data.write(to: url, options: .atomic)
            } else {
                try data.write(to: url, options: .atomic)
            }
            lastIOError = nil
        } catch {
            lastIOError = error.localizedDescription
            throw error
        }
    }

    func select(_ url: URL?) {
        let normalized = url.map { URL(fileURLWithPath: $0.path).standardizedFileURL }
        guard normalized != selectedURL else { return }
        saveTask?.cancel()
        saveSynchronouslyForCurrentSelection()
        selectedURL = normalized
        guard let url = normalized else {
            isApplyingLoad = true
            text = ""
            Task { @MainActor in
                self.isApplyingLoad = false
            }
            return
        }
        let token = UUID()
        loadToken = token
        let data = readFileData(at: url)
        guard loadToken == token else { return }
        let s = String(data: data, encoding: .utf8) ?? ""
        isApplyingLoad = true
        text = s
        // Let SwiftUI / onChange see isApplyingLoad == true for this turn so we do not treat load as a user edit.
        Task { @MainActor in
            self.isApplyingLoad = false
        }
    }

    func reloadFromDisk() {
        guard let url = selectedURL else { return }
        let token = UUID()
        loadToken = token
        let data = readFileData(at: url)
        guard loadToken == token else { return }
        let s = String(data: data, encoding: .utf8) ?? ""
        isApplyingLoad = true
        text = s
        Task { @MainActor in
            self.isApplyingLoad = false
        }
    }

    /// Call when `text` changes from user editing (not from disk load).
    func scheduleSaveAfterEdit() {
        guard !isApplyingLoad, let url = selectedURL else { return }
        let snapshot = text
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, self.selectedURL == url else { return }
            do {
                try self.writeFileData(Data(snapshot.utf8), to: url)
            } catch {
                DiagnosticLog.log("MasterFolder: save failed: \(error)")
            }
        }
    }

    private func saveSynchronouslyForCurrentSelection() {
        guard let url = selectedURL else { return }
        do {
            try writeFileData(Data(text.utf8), to: url)
        } catch {
            DiagnosticLog.log("MasterFolder: save before switch failed: \(error)")
        }
    }
}

// MARK: - Characters strip (box palette only)

struct KindasCharactersStripView: View {
    @Binding var boxCells: [String]
    @State private var editSquares = false
    var fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)
                Button {
                    editSquares.toggle()
                    boxCells = normalizedBoxCells(from: boxCells)
                } label: {
                    Image(systemName: editSquares ? "square.grid.3x3" : "square.and.pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
                .help(editSquares ? "Copy mode — tap a cell to copy to clipboard" : "Edit squares — one character per cell")
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if editSquares {
                BoxCharacterEditGridView(cells: $boxCells, fontSize: fontSize)
            } else {
                BoxCharacterPaletteView(cells: $boxCells, fontSize: fontSize)
            }
        }
        .background(Theme.backgroundColorSwiftUI)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func normalizedBoxCells(from cells: [String]) -> [String] {
        var c = cells
        while c.count < KindasBoxGridConfig.cellCount {
            c.append(" ")
        }
        c = Array(c.prefix(KindasBoxGridConfig.cellCount))
        return c.map { KindasBoxGridConfig.normalizeCell($0) }
    }
}

// MARK: - MASTER strip (picker + scratch editor; bottom of column — `charactersVisible` adjusts scratch height vs box strip)

/// MASTER scratch `BlueprintEditorView` heights (readable scratch without eating the whole window).
private enum MasterBlueprintLayout {
    static let minHeightWithCharacters: CGFloat = 34
    static let minHeightCharactersHidden: CGFloat = 42
}

struct KindasMasterStripView: View {
    @ObservedObject var masterModel: MasterFolderModel
    var fontSize: CGFloat
    /// When the box-character strip is hidden, tighten chrome and let the scratch editor grow vertically.
    var charactersVisible: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("Master")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Picker("File", selection: Binding<Int>(
                    get: {
                        guard let s = masterModel.selectedURL else { return -1 }
                        return masterModel.fileURLs.firstIndex(where: { $0.path == s.path }) ?? -1
                    },
                    set: { idx in
                        if idx < 0 {
                            masterModel.select(nil)
                        } else if idx < masterModel.fileURLs.count {
                            masterModel.select(masterModel.fileURLs[idx])
                        }
                    }
                )) {
                    Text("—").tag(-1)
                    ForEach(Array(masterModel.fileURLs.enumerated()), id: \.element.path) { idx, url in
                        Text(url.lastPathComponent).tag(idx)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    masterModel.chooseMasterFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
                .help("Choose MASTER folder…")
            }
            .padding(.horizontal, 10)
            .padding(.top, charactersVisible ? 6 : 2)
            .padding(.bottom, charactersVisible ? 4 : 3)

            BlueprintEditorView(text: $masterModel.text, fontSize: fontSize)
                .id(masterModel.selectedURL?.path ?? "__master_none__")
                .frame(
                    minHeight: charactersVisible
                        ? MasterBlueprintLayout.minHeightWithCharacters
                        : MasterBlueprintLayout.minHeightCharactersHidden,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .background(Theme.backgroundColorSwiftUI)
                .onChange(of: masterModel.text) { _, _ in
                    masterModel.scheduleSaveAfterEdit()
                }

            if let err = masterModel.lastIOError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(Color.red)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
            }
        }
        .frame(minHeight: charactersVisible ? 83 : 131, maxHeight: 238, alignment: .top)
        .background(Theme.backgroundColorSwiftUI)
        .onAppear {
            masterModel.ensureFolderAndRefresh()
        }
    }
}
