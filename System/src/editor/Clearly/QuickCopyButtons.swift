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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd:HHmm"
        return f
    }()

    var dateString: String { Self.dateFormatter.string(from: Date()) }

    private static func defaultItems() -> [QuickCopyItem] {
        [
            QuickCopyItem(label: "Slot 1", content: ""),
            QuickCopyItem(label: "Slot 2", content: ""),
            QuickCopyItem(label: "Slot 3", content: "")
        ]
    }

    func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func copyDateString() {
        copyToClipboard(dateString)
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode([QuickCopyItem].self, from: data) else { return }
        items = decoded
    }

    func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - Quick Copy Buttons View

struct QuickCopyButtonsView: View {
    @StateObject private var model = QuickCopyModel()

    var body: some View {
        HStack(spacing: 3) {
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

            ForEach(0..<min(3, model.items.count), id: \.self) { index in
                let hasContent = !model.items[index].content.isEmpty
                Button {
                    model.copyToClipboard(model.items[index].content)
                } label: {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 11))
                        .foregroundStyle(hasContent ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
                .help(hasContent
                    ? "Slot \(index + 1): \(model.items[index].content.prefix(50))"
                    : "Slot \(index + 1): empty")
            }

            Divider().frame(height: 14)

            Button {
                model.isEditing.toggle()
            } label: {
                Image(systemName: model.isEditing ? "checkmark.circle.fill" : "pencil.line")
                    .font(.system(size: 11))
                    .foregroundStyle(model.isEditing ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 20)
            .contentShape(Rectangle())
            .help(model.isEditing ? "Done" : "Edit clips")
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
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK COPY SLOTS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .tracking(1)

            ForEach(model.items.indices.prefix(3), id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Slot \(index + 1)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Type content to copy…", text: Binding(
                        get: { model.items[index].content },
                        set: { newValue in
                            model.items[index].content = newValue
                            model.saveItems()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                }
            }

            Text("Click slot icon to copy to clipboard")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 260)
    }
}
