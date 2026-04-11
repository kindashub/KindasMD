import AppKit
import SwiftUI

// MARK: - Box character grid (copy to clipboard; optional edit layout)

enum KindasBoxGridConfig {
    /// Full-width strip grid: 41 columns × 4 rows, single char per cell.
    static let columnsPerRow = 41
    static let rowCount = 4
    static var cellCount: Int { columnsPerRow * rowCount }

    /// Upper-right cell of row 1 — reserved for the edit-mode toggle button.
    static let editButtonIndex = columnsPerRow - 1

    static func defaultCells() -> [String] {
        return Array(repeating: " ", count: cellCount)
    }

    /// Single extended grapheme per palette cell; empty input becomes a visible space.
    static func normalizeCell(_ s: String) -> String {
        let t = s.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        if t.isEmpty { return " " }
        return String(t.first!)
    }
}

struct BoxCharacterPaletteView: View {
    @Binding var cells: [String]
    var fontSize: CGFloat
    var onEditToggle: () -> Void

    private let hPad: CGFloat = 9
    private let vPad: CGFloat = 8
    private let spacing: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<KindasBoxGridConfig.rowCount, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<KindasBoxGridConfig.columnsPerRow, id: \.self) { col in
                        let index = row * KindasBoxGridConfig.columnsPerRow + col
                        if index == KindasBoxGridConfig.editButtonIndex {
                            editToggleButton()
                        } else {
                            boxCell(character: safeCharacter(at: index))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
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

    @ViewBuilder
    private func editToggleButton() -> some View {
        Button { onEditToggle() } label: {
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: Theme.backgroundColor).opacity(0.55))
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.secondary.opacity(0.32), lineWidth: 0.5)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: max(8, s * 0.45)))
                        .foregroundStyle(.secondary)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .help("Edit squares — one character per cell")
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
    var onEditToggle: () -> Void

    private let hPad: CGFloat = 9
    private let vPad: CGFloat = 8
    private let spacing: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<KindasBoxGridConfig.rowCount, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<KindasBoxGridConfig.columnsPerRow, id: \.self) { col in
                        let index = row * KindasBoxGridConfig.columnsPerRow + col
                        if index == KindasBoxGridConfig.editButtonIndex {
                            editToggleButton()
                        } else {
                            editCell(at: index)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: 96)
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
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

    @ViewBuilder
    private func editToggleButton() -> some View {
        Button { onEditToggle() } label: {
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: Theme.backgroundColor).opacity(0.55))
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.5)
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: max(8, s * 0.45)))
                        .foregroundStyle(.secondary)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .help("Copy mode — tap a cell to copy to clipboard")
    }
}

// MARK: - Characters strip (box palette only)

struct KindasCharactersStripView: View {
    @Binding var boxCells: [String]
    @State private var editSquares = false
    var fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if editSquares {
                BoxCharacterEditGridView(cells: $boxCells, fontSize: fontSize, onEditToggle: {
                    editSquares = false
                    boxCells = normalizedBoxCells(from: boxCells)
                })
            } else {
                BoxCharacterPaletteView(cells: $boxCells, fontSize: fontSize, onEditToggle: {
                    editSquares = true
                })
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
