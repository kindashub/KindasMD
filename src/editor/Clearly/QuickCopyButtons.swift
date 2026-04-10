import AppKit
import SwiftUI

// MARK: - Quick Copy Item Model

struct QuickCopyItem: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var content: String

    init(id: UUID = UUID(), label: String, content: String) {
        self.id = id
        self.label = label
        self.content = content
    }
}

// MARK: - Quick Copy Model

@MainActor
final class QuickCopyModel: ObservableObject {
    private static let storageKey = "kindasQuickCopyItems_v2"

    @Published var items: [QuickCopyItem] = []
    @Published var isEditing = false

    init() {
        loadItems()
        if items.isEmpty {
            items = Self.defaultItems()
            saveItems()
        }
    }

    /// Computed date string in YYYYMMDD:HHMM format, evaluated at copy time
    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd:HHmm"
        return formatter.string(from: Date())
    }

    private static func defaultItems() -> [QuickCopyItem] {
        [
            QuickCopyItem(label: "S1", content: ""),
            QuickCopyItem(label: "S2", content: ""),
            QuickCopyItem(label: "S3", content: "")
        ]
    }

    func copyItem(_ item: QuickCopyItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.content, forType: .string)
    }

    func copyDateString() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(dateString, forType: .string)
    }

    func updateContent(for id: UUID, to newContent: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].content = newContent
        saveItems()
    }

    func updateLabel(for id: UUID, to newLabel: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].label = newLabel
        saveItems()
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode([QuickCopyItem].self, from: data) else { return }
        items = decoded
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - Quick Copy Buttons View

struct QuickCopyButtonsView: View {
    @StateObject private var model = QuickCopyModel()

    var body: some View {
        HStack(spacing: 6) {
            // Date button: calendar icon, copies YYYYMMDD:HHMM (not editable)
            Button {
                model.copyDateString()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 20)
            .contentShape(Rectangle())
            .help("Copy date: \(model.dateString)")

            // S1/S2/S3 buttons: flat text labels with subtle border, editable
            ForEach(model.items.prefix(3)) { item in
                Button {
                    model.copyItem(item)
                } label: {
                    Text(item.label)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(item.content.isEmpty ? .tertiary : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 26, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .help(item.content.isEmpty ? "\(item.label): (empty)" : "\(item.label): \(item.content.prefix(50))\(item.content.count > 50 ? "…" : "")")
            }

            Divider()
                .frame(height: 16)

            // Edit button
            Button {
                model.isEditing.toggle()
            } label: {
                Image(systemName: model.isEditing ? "checkmark.circle.fill" : "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(model.isEditing ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 20)
            .contentShape(Rectangle())
            .help(model.isEditing ? "Done editing clips" : "Edit S1/S2/S3 clips")
        }
        .popover(isPresented: $model.isEditing, arrowEdge: .bottom) {
            QuickCopyEditPanel(model: model)
        }
    }
}

// MARK: - Quick Copy Edit Panel

struct QuickCopyEditPanel: View {
    @ObservedObject var model: QuickCopyModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUICK COPY SLOTS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .tracking(1)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Only show S1/S2/S3 (editable slots), not the Date button
            VStack(alignment: .leading, spacing: 8) {
                ForEach($model.items.prefix(3)) { $item in
                    QuickCopyEditRow(item: $item, onUpdate: { newContent in
                        model.updateContent(for: item.id, to: newContent)
                    }, onLabelUpdate: { newLabel in
                        model.updateLabel(for: item.id, to: newLabel)
                    })
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

            HStack {
                Spacer()
                Text("Date button copies YYYYMMDD:HHMM")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 240, height: 200)
    }
}

// MARK: - Quick Copy Edit Row

struct QuickCopyEditRow: View {
    @Binding var item: QuickCopyItem
    let onUpdate: (String) -> Void
    let onLabelUpdate: (String) -> Void
    @State private var isHovered = false
    @FocusState private var isContentFocused: Bool
    @FocusState private var isLabelFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Label", text: Binding(
                    get: { item.label },
                    set: { newValue in
                        item.label = newValue
                        onLabelUpdate(newValue)
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .focused($isLabelFocused)
                .frame(width: 60)

                TextEditor(text: Binding(
                    get: { item.content },
                    set: { newValue in
                        item.content = newValue
                        onUpdate(newValue)
                    }
                ))
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .focused($isContentFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(height: 40)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
