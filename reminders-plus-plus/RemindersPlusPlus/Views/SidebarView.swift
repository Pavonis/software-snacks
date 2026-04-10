import SwiftUI

/// Sidebar showing smart lists and user reminder lists, similar to Apple Reminders.
struct SidebarView: View {
    @Environment(ReminderStore.self) private var store

    @Binding var selectedSmartList: SmartList?
    @Binding var selectedList: ReminderList?
    @Binding var showingNewList: Bool

    @State private var editingList: ReminderList?
    @State private var showingDiagnostics = false

    var body: some View {
        List(selection: Binding(
            get: { selectionValue },
            set: { handleSelection($0) }
        )) {
            smartListsSection
            userListsSection
        }
        .listStyle(.sidebar)
        .navigationTitle("Reminders++")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    showingNewList = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add List")
                    }
                    .font(.callout.bold())
                }
                Spacer()
                Button {
                    showingDiagnostics = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(item: $editingList) { list in
            ListEditorView(mode: .edit(list))
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
        }
        .task {
            store.refreshLists()
            await store.refreshSmartListCounts()
        }
    }

    // MARK: - Smart Lists

    private var smartListsSection: some View {
        Section {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SmartList.allCases) { smart in
                    SmartListCard(
                        smartList: smart,
                        count: store.smartListCounts[smart] ?? 0,
                        isSelected: selectedSmartList == smart
                    )
                    .onTapGesture {
                        selectedSmartList = smart
                        selectedList = nil
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - User Lists

    private var userListsSection: some View {
        Section("My Lists") {
            ForEach(store.lists) { list in
                HStack {
                    Image(systemName: "list.bullet.circle.fill")
                        .font(.title2)
                        .foregroundStyle(list.color)

                    Text(list.title)
                        .lineLimit(1)

                    Spacer()

                    if let count = list.reminderCount {
                        Text("\(count)")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
                .tag(SidebarSelection.list(list.id))
                .contextMenu {
                    Button {
                        editingList = list
                    } label: {
                        Label("Edit List", systemImage: "pencil")
                    }

                    if list.allowsModifications {
                        Button(role: .destructive) {
                            try? store.deleteList(list)
                        } label: {
                            Label("Delete List", systemImage: "trash")
                        }
                    }

                    Divider()

                    Text("Source: \(list.sourceName)")
                }
                .swipeActions(edge: .trailing) {
                    if list.allowsModifications {
                        Button(role: .destructive) {
                            try? store.deleteList(list)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Selection Handling

    private enum SidebarSelection: Hashable {
        case smart(SmartList)
        case list(String)
    }

    private var selectionValue: SidebarSelection? {
        if let smart = selectedSmartList { return .smart(smart) }
        if let list = selectedList { return .list(list.id) }
        return nil
    }

    private func handleSelection(_ selection: SidebarSelection?) {
        switch selection {
        case .smart(let smart):
            selectedSmartList = smart
            selectedList = nil
        case .list(let id):
            selectedList = store.lists.first { $0.id == id }
            selectedSmartList = nil
        case nil:
            selectedSmartList = nil
            selectedList = nil
        }
    }
}

// MARK: - Smart List Card

private struct SmartListCard: View {
    let smartList: SmartList
    let count: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: smartList.icon)
                    .font(.title2)
                    .foregroundStyle(smartList.tintColor)
                Spacer()
                Text("\(count)")
                    .font(.title2.bold())
            }
            Text(smartList.title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? smartList.tintColor.opacity(0.15) : Color(.systemGray6))
        )
    }
}

// MARK: - Diagnostics View

/// Shows EventKit API diagnostic info — useful for evaluating the API surface.
private struct DiagnosticsView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let diagnostics = store.diagnosticSummary()
                Section("EventKit API Surface") {
                    ForEach(Array(diagnostics.keys.sorted()), id: \.self) { key in
                        LabeledContent(key, value: diagnostics[key] ?? "—")
                    }
                }

                Section("Available Sources") {
                    ForEach(store.availableSources(), id: \.name) { source in
                        LabeledContent(source.name, value: source.type.displayName)
                    }
                }

                Section("Known Limitations") {
                    Text("• Subtasks: No public API for parent/child relationships")
                    Text("• Tags: iOS 17 tags not accessible via EventKit")
                    Text("• Custom Sort Order: Not preserved through EventKit")
                    Text("• Attachments/Images: Not exposed")
                    Text("• Templates: Not exposed")
                    Text("• Board/Column View: Not exposed")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("API Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SidebarView(
            selectedSmartList: .constant(nil),
            selectedList: .constant(nil),
            showingNewList: .constant(false)
        )
        .environment(ReminderStore())
    }
}
