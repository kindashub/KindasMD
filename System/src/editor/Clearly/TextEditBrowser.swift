import AppKit
import Darwin
import SwiftUI

// MARK: - TextEdit Browser Model

@MainActor
final class TextEditBrowserModel: ObservableObject {
    @Published var files: [TextEditFile] = []
    @Published var lastError: String?

    private var watchSource: DispatchSourceFileSystemObject?
    private var watchedPath: String?

    struct TextEditFile: Identifiable, Comparable {
        let id = UUID()
        let url: URL
        let name: String
        let modified: Date

        static func < (lhs: TextEditFile, rhs: TextEditFile) -> Bool {
            lhs.modified > rhs.modified  // Newest first
        }
    }

    deinit {
        // Cancel watch source on deinit (DispatchSource is thread-safe)
        watchSource?.cancel()
    }

    /// Real `~/…` — **not** the sandbox container. Prefer `getpwuid` first.
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
        return FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
    }

    private static var textMDURL: URL {
        resolvedUserHomeURL()
            .appendingPathComponent("TextMD", isDirectory: true)
    }

    func refresh() {
        let fm = FileManager.default
        let dir = Self.textMDURL

        // Ensure directory exists
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            lastError = "Could not create TextMD folder"
            DiagnosticLog.log("TextEditBrowser: createDirectory failed: \(error)")
        }

        // List .md files
        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            lastError = error.localizedDescription
            DiagnosticLog.log("TextEditBrowser: contentsOfDirectory failed: \(error)")
            files = []
            setupWatch(path: dir.path)
            return
        }

        var mdFiles: [TextEditFile] = []
        for url in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            guard url.pathExtension.lowercased() == "md" else { continue }

            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let modified = attrs?[.modificationDate] as? Date ?? Date.distantPast

            mdFiles.append(TextEditFile(
                url: url,
                name: url.lastPathComponent,
                modified: modified
            ))
        }

        files = mdFiles.sorted()
        lastError = nil
        setupWatch(path: dir.path)
    }

    /// Callback for when a file is selected. The caller (ContentView) handles the actual file switching.
    var onFileSelected: ((URL) -> Void)?

    func openFile(_ file: TextEditFile) {
        // Notify the parent view to handle the file switch in-place
        onFileSelected?(file.url)
    }

    // MARK: - File Watching

    private func stopWatching() {
        watchSource?.cancel()
        watchSource = nil
        watchedPath = nil
    }

    private func setupWatch(path: String) {
        guard path != watchedPath else { return }
        stopWatching()

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            DiagnosticLog.log("TextEditBrowser: could not open watch descriptor for \(path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.refresh()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        watchSource = source
        watchedPath = path
        DiagnosticLog.log("TextEditBrowser: watching \(path)")
    }
}

// MARK: - TextEdit Browser View

struct TextEditBrowserView: View {
    @ObservedObject var model: TextEditBrowserModel
    var onFileSelected: ((URL) -> Void)?

    init(model: TextEditBrowserModel, onFileSelected: ((URL) -> Void)? = nil) {
        self.model = model
        self.onFileSelected = onFileSelected
        // Wire the callback to the model
        model.onFileSelected = onFileSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TEXTMD FILES")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .tracking(1)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if model.files.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No .md files in TextMD")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.files) { file in
                            TextEditFileRow(file: file) {
                                // Direct callback - more reliable than going through model
                                onFileSelected?(file.url)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }

            if let err = model.lastError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(Color.red)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
        }
        .frame(width: 200)
        .onAppear {
            model.refresh()
        }
    }
}

// MARK: - TextEdit File Row

private struct TextEditFileRow: View {
    let file: TextEditBrowserModel.TextEditFile
    let onTap: () -> Void
    @State private var isHovered = false

    private var dateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: file.modified, relativeTo: Date())
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(dateText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Open \(file.name)")
    }
}
