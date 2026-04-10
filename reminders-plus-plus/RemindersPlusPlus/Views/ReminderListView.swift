import SwiftUI

/// Displays reminders for a selected list or smart list, with inline add.
struct ReminderListView: View {
    @Environment(ReminderStore.self) private var store

    let source: ReminderSource
    @State private var reminders: [ReminderItem] = []
    @State private var isLoading = true
    @State private var showCompleted = false
    @State private var newReminderTitle = ""
    @State private var isAddingReminder = false
    @State private var selectedReminder: ReminderItem?
    @State private var sortOrder: SortOrder = .manual

    enum SortOrder: String, CaseIterable {
        case manual = "Manual"
        case dueDate = "Due Date"
        case priority = "Priority"
        case title = "Title"
        case creationDate = "Created"
    }

    var body: some View {
        List {
            if !incompleteReminders.isEmpty || isAddingReminder {
                Section {
                    ForEach(incompleteReminders) { item in
                        ReminderRowView(
                            item: item,
                            onToggle: { toggleCompletion(item) },
                            onTap: { selectedReminder = item }
                        )
                    }
                    .onDelete { offsets in
                        deleteReminders(at: offsets)
                    }

                    if isAddingReminder {
                        newReminderRow
                    }
                }
            }

            if showCompleted && !completedReminders.isEmpty {
                Section("Completed") {
                    ForEach(completedReminders) { item in
                        ReminderRowView(
                            item: item,
                            onToggle: { toggleCompletion(item) },
                            onTap: { selectedReminder = item }
                        )
                    }
                }
            }

            if reminders.isEmpty && !isLoading && !isAddingReminder {
                ContentUnavailableView(
                    "No Reminders",
                    systemImage: "checkmark.circle",
                    description: Text("Tap + to create a new reminder.")
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(source.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Section("Sort By") {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Toggle("Show Completed", isOn: $showCompleted)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    isAddingReminder = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Reminder")
                    }
                    .font(.callout.bold())
                }
            }
        }
        .sheet(item: $selectedReminder) { item in
            ReminderDetailView(item: item, listSource: source)
        }
        .refreshable {
            await loadReminders()
        }
        .task {
            await loadReminders()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    // MARK: - New Reminder Row

    private var newReminderRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(.tertiary)

            TextField("New Reminder", text: $newReminderTitle)
                .textFieldStyle(.plain)
                .onSubmit {
                    createReminder()
                }

            Button("Cancel") {
                newReminderTitle = ""
                isAddingReminder = false
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed

    private var incompleteReminders: [ReminderItem] {
        sorted(reminders.filter { !$0.isCompleted })
    }

    private var completedReminders: [ReminderItem] {
        reminders.filter { $0.isCompleted }
    }

    private func sorted(_ items: [ReminderItem]) -> [ReminderItem] {
        switch sortOrder {
        case .manual:
            return items
        case .dueDate:
            return items.sorted { a, b in
                guard let aDate = a.dueDate else { return false }
                guard let bDate = b.dueDate else { return true }
                return aDate < bDate
            }
        case .priority:
            return items.sorted { a, b in
                if a.priority == 0 { return false }
                if b.priority == 0 { return true }
                return a.priority < b.priority
            }
        case .title:
            return items.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .creationDate:
            return items.sorted { a, b in
                guard let aDate = a.creationDate else { return false }
                guard let bDate = b.creationDate else { return true }
                return aDate > bDate
            }
        }
    }

    // MARK: - Actions

    private func loadReminders() async {
        isLoading = true
        defer { isLoading = false }

        switch source {
        case .smart(let smart):
            switch smart {
            case .today: reminders = await store.fetchTodayReminders()
            case .scheduled: reminders = await store.fetchScheduledReminders()
            case .all: reminders = await store.fetchAllReminders()
            case .flagged: reminders = await store.fetchFlaggedReminders()
            case .completed:
                reminders = await store.fetchCompletedReminders()
                showCompleted = true
            }
        case .list(let list):
            reminders = await store.fetchReminders(in: list)
        }
    }

    private func toggleCompletion(_ item: ReminderItem) {
        do {
            let updated = try store.toggleCompletion(item)
            if let index = reminders.firstIndex(where: { $0.id == item.id }) {
                reminders[index] = updated
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func createReminder() {
        guard !newReminderTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            isAddingReminder = false
            return
        }

        if case .list(let list) = source {
            do {
                let item = try store.createReminder(title: newReminderTitle, in: list)
                reminders.append(item)
                newReminderTitle = ""
                isAddingReminder = false
            } catch {
                store.errorMessage = error.localizedDescription
            }
        } else if let defaultList = store.defaultList() {
            do {
                let item = try store.createReminder(title: newReminderTitle, in: defaultList)
                reminders.append(item)
                newReminderTitle = ""
                isAddingReminder = false
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteReminders(at offsets: IndexSet) {
        let items = offsets.map { incompleteReminders[$0] }
        for item in items {
            try? store.deleteReminder(item)
            reminders.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - Reminder Source

enum ReminderSource: Hashable {
    case smart(SmartList)
    case list(ReminderList)

    var title: String {
        switch self {
        case .smart(let smart): return smart.title
        case .list(let list): return list.title
        }
    }
}

#Preview {
    NavigationStack {
        ReminderListView(source: .smart(.all))
            .environment(ReminderStore())
    }
}
