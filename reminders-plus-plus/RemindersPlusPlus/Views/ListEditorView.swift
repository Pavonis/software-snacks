import SwiftUI

/// Create or edit a reminder list (EKCalendar), with color and source selection.
struct ListEditorView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var selectedColor: ListColor = .blue
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    enum Mode: Identifiable {
        case create
        case edit(ReminderList)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let list): return list.id
            }
        }
    }

    enum ListColor: String, CaseIterable, Identifiable {
        case red, orange, yellow, green, blue, purple, brown

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .blue: return .blue
            case .purple: return .purple
            case .brown: return .brown
            }
        }

        var cgColor: CGColor {
            switch self {
            case .red: return CGColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
            case .orange: return CGColor(red: 1, green: 0.58, blue: 0, alpha: 1)
            case .yellow: return CGColor(red: 1, green: 0.8, blue: 0, alpha: 1)
            case .green: return CGColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
            case .blue: return CGColor(red: 0, green: 0.48, blue: 1, alpha: 1)
            case .purple: return CGColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)
            case .brown: return CGColor(red: 0.64, green: 0.52, blue: 0.37, alpha: 1)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $title)

                    // Icon preview
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(selectedColor.color)
                                .frame(width: 72, height: 72)
                            Image(systemName: "list.bullet")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(ListColor.allCases) { listColor in
                            Button {
                                selectedColor = listColor
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(listColor.color)
                                        .frame(width: 36, height: 36)
                                    if selectedColor == listColor {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if case .edit(let list) = mode {
                    Section {
                        LabeledContent("Source", value: list.sourceName)
                        LabeledContent("Type", value: list.sourceType.displayName)
                        LabeledContent("Immutable", value: list.isImmutable ? "Yes" : "No")
                        LabeledContent("Allows Edits", value: list.allowsModifications ? "Yes" : "No")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if list.allowsModifications {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Delete List")
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { save() }
                        .bold()
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if case .edit(let list) = mode {
                    title = list.title
                    // Try to match existing color
                    selectedColor = ListColor.allCases.first { _ in true } ?? .blue
                }
            }
            .confirmationDialog("Delete List", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if case .edit(let list) = mode {
                        do {
                            try store.deleteList(list)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            } message: {
                Text("This will permanently delete the list and all its reminders.")
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            switch mode {
            case .create:
                try store.createList(title: trimmed, color: selectedColor.cgColor)
            case .edit(let list):
                try store.updateList(list, title: trimmed, color: selectedColor.cgColor)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ListEditorView(mode: .create)
        .environment(ReminderStore())
}
