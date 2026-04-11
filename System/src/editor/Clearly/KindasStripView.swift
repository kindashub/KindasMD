import AppKit
import SwiftUI

// MARK: - Box character grid (copy to clipboard; optional edit layout)

enum KindasBoxGridConfig {
    /// Full-width strip grid: 41 columns × 4 rows (single char), plus row 5 (20 cols × 2 chars), plus row 6 (10 cols × 4 chars).
    static let columnsPerRow = 41      // For rows 1-4
    static let row5Columns = 20        // Row 5: 2-char cells
    static let row6Columns = 10      // Row 6: 4-char cells
    static let rowCount = 6
    static let row5CharLimit = 2
    static let row6CharLimit = 4

    /// Total cells: (4 × 41) + 20 + 10 = 194
    static var cellCount: Int { (columnsPerRow * 4) + row5Columns + row6Columns }

    static func defaultCells() -> [String] {
        // Rows 1-4: 164 single-character cells (existing content)
        let rawRows1to4 =
            "╌─═━╎│║┃█░▒▓⦿┌┐└┘├┤┬┴┼╔╗╚╝╠╣╦╩╬·•□■○●★☆§→←↑↓"
            + "╴╵╶╷╸╹╺╻╼╽╾╿┏┓┗┛┳┻╋┣┫╍╏═╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫"
            + "▀▄▌▐▖▗▘▝▞▟▁▂▃▄▅▆▇█░▒▓▔▕▖▗▘▙▚▛▜▝▞▟"
            + "⋯⋮⋯⌘⌥⇧⌃⌤␣¶†‡※‰♠♣♥♦✓✗⊢⊣⊤⊥⊦⊧⊨⊩⊪⊫⊬⊭⊮⊯"

        // Row 5: 20 two-character cells (default: box-drawing pairs)
        let row5Defaults = [
            "──", "══", "━━", "││", "║║", "┌┐", "└┘", "├┤", "┬┴", "┼┼",
            "╔╗", "╚╝", "╠╣", "╦╩", "╬╬", "▌▐", "▖▗", "▘▝", "▙▟", "▚▞"
        ]

        // Row 6: 10 four-character cells (default: patterns)
        let row6Defaults = [
            "────", "════", "━━━━", "····", "░░░░", "▒▒▒▒", "▓▓▓▓", "████", "→→→→", "⇒⇒⇒⇒"
        ]

        var cells = rawRows1to4.map { String($0) }
        // Pad rows 1-4 to exactly 164 cells if needed
        while cells.count < (columnsPerRow * 4) {
            cells.append(" ")
        }
        // Add row 5 and row 6
        cells.append(contentsOf: row5Defaults)
        cells.append(contentsOf: row6Defaults)

        return Array(cells.prefix(cellCount))
    }

    /// Normalize cell content: truncate to maxLength, remove newlines, empty becomes space.
    static func normalizeCell(_ s: String, maxLength: Int = 1) -> String {
        let t = s.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        if t.isEmpty { return " " }
        // Take up to maxLength characters from the start
        let endIndex = t.index(t.startIndex, offsetBy: min(maxLength, t.count))
        return String(t[..<endIndex])
    }

    /// Get max character limit for a given cell index
    static func charLimit(forIndex index: Int) -> Int {
        if index < (columnsPerRow * 4) {
            return 1  // Rows 1-4: single char
        } else if index < (columnsPerRow * 4) + row5Columns {
            return row5CharLimit  // Row 5: 2 chars
        } else {
            return row6CharLimit    // Row 6: 4 chars
        }
    }

    /// Get column count for a given row index (0-based)
    static func columns(forRow row: Int) -> Int {
        switch row {
        case 0, 1, 2, 3: return columnsPerRow  // Rows 1-4
        case 4: return row5Columns              // Row 5
        case 5: return row6Columns              // Row 6
        default: return columnsPerRow
        }
    }
}

struct BoxCharacterPaletteView: View {
    @Binding var cells: [String]
    var fontSize: CGFloat

    private let hPad: CGFloat = 12
    private let spacing: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // Rows 1-4: 41 columns, 1 char per cell, 1:1 aspect ratio
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<KindasBoxGridConfig.columnsPerRow, id: \.self) { col in
                        let index = row * KindasBoxGridConfig.columnsPerRow + col
                        boxCell(character: safeCharacter(at: index), fontScale: 0.72)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Row 5: 20 columns, 2 chars per cell, 2:1 aspect ratio (wider cells)
            HStack(spacing: spacing) {
                ForEach(0..<KindasBoxGridConfig.row5Columns, id: \.self) { col in
                    let index = (KindasBoxGridConfig.columnsPerRow * 4) + col
                    boxCell(character: safeCharacter(at: index), fontScale: 0.65, aspectRatio: 2.0)
                }
            }
            .frame(maxWidth: .infinity)

            // Row 6: 10 columns, 4 chars per cell, 4:1 aspect ratio (even wider)
            HStack(spacing: spacing) {
                ForEach(0..<KindasBoxGridConfig.row6Columns, id: \.self) { col in
                    let index = (KindasBoxGridConfig.columnsPerRow * 4) + KindasBoxGridConfig.row5Columns + col
                    boxCell(character: safeCharacter(at: index), fontScale: 0.60, aspectRatio: 4.0)
                }
            }
            .frame(maxWidth: .infinity)
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
    private func boxCell(character: String, fontScale: CGFloat, aspectRatio: CGFloat = 1.0) -> some View {
        let ch = character
        Button {
            copyToPasteboard(ch)
        } label: {
            GeometryReader { geo in
                let s = min(geo.size.width / aspectRatio, geo.size.height)
                let cellFontSize = max(8, min(s * 0.65, fontSize * fontScale))
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: Theme.backgroundColor).opacity(0.55))
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.secondary.opacity(0.32), lineWidth: 0.5)
                    Text(ch.isEmpty ? " " : ch)
                        .font(.system(size: cellFontSize, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .minimumScaleFactor(0.30)
                        .lineLimit(1)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
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

    private let hPad: CGFloat = 12
    private let spacing: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // Rows 1-4: 41 columns, 1 char per cell
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<KindasBoxGridConfig.columnsPerRow, id: \.self) { col in
                        let index = row * KindasBoxGridConfig.columnsPerRow + col
                        editCell(at: index, fontScale: 0.72, aspectRatio: 1.0)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Row 5: 20 columns, 2 chars per cell
            HStack(spacing: spacing) {
                ForEach(0..<KindasBoxGridConfig.row5Columns, id: \.self) { col in
                    let index = (KindasBoxGridConfig.columnsPerRow * 4) + col
                    editCell(at: index, fontScale: 0.65, aspectRatio: 2.0)
                }
            }
            .frame(maxWidth: .infinity)

            // Row 6: 10 columns, 4 chars per cell
            HStack(spacing: spacing) {
                ForEach(0..<KindasBoxGridConfig.row6Columns, id: \.self) { col in
                    let index = (KindasBoxGridConfig.columnsPerRow * 4) + KindasBoxGridConfig.row5Columns + col
                    editCell(at: index, fontScale: 0.60, aspectRatio: 4.0)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, hPad)
    }

    private func cellBinding(at index: Int) -> Binding<String> {
        let maxLength = KindasBoxGridConfig.charLimit(forIndex: index)
        return Binding(
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
                next[index] = KindasBoxGridConfig.normalizeCell(newValue, maxLength: maxLength)
                cells = next
            }
        )
    }

    @ViewBuilder
    private func editCell(at index: Int, fontScale: CGFloat, aspectRatio: CGFloat) -> some View {
        GeometryReader { geo in
            let s = min(geo.size.width / aspectRatio, geo.size.height)
            let cellFontSize = max(8, min(s * 0.65, fontSize * fontScale))
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: Theme.backgroundColor).opacity(0.55))
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.5)
                TextField("", text: cellBinding(at: index))
                    .textFieldStyle(.plain)
                    .font(.system(size: cellFontSize, design: .monospaced))
                    .foregroundColor(Color.accentColor)
                    .tint(Color.accentColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.30)
                    .padding(2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .help("Max \(KindasBoxGridConfig.charLimit(forIndex: index)) character(s)")
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
