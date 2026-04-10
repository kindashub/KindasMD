import AppKit
import Darwin
import SwiftUI

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
