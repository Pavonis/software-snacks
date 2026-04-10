import SwiftUI

/// Full-screen search across all reminders (complete and incomplete).
struct SearchView: View {
    @Environment(ReminderStore.self) private var store
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var results: [ReminderItem] = []
    @State private var isSearching = false
    @State private var selectedReminder: ReminderItem?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search reminders", text: $query)
                            .focused($isSearchFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { performSearch() }
                            .onChange(of: query) { _, newValue in
                                if newValue.count >= 2 {
                                    performSearch()
                                } else if newValue.isEmpty {
                                    results = []
                                }
                            }
                        if !query.isEmpty {
                            Button {
                                query = ""
                                results = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)

                    Button("Cancel") {
                        isPresented = false
                    }
                }
                .padding()

                // Results
                if isSearching {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        // Group by list
                        let grouped = Dictionary(grouping: results) { $0.listTitle }
                        ForEach(Array(grouped.keys.sorted()), id: \.self) { listTitle in
                            Section(listTitle) {
                                ForEach(grouped[listTitle] ?? []) { item in
                                    ReminderRowView(
                                        item: item,
                                        onToggle: { toggleCompletion(item) },
                                        onTap: { selectedReminder = item }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .sheet(item: $selectedReminder) { item in
                ReminderDetailView(item: item, listSource: .smart(.all))
            }
            .onAppear {
                isSearchFocused = true
            }
        }
        .background(Color(.systemBackground))
    }

    private func performSearch() {
        let currentQuery = query
        isSearching = true
        Task {
            results = await store.searchReminders(query: currentQuery)
            isSearching = false
        }
    }

    private func toggleCompletion(_ item: ReminderItem) {
        do {
            let updated = try store.toggleCompletion(item)
            if let index = results.firstIndex(where: { $0.id == item.id }) {
                results[index] = updated
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SearchView(isPresented: .constant(true))
        .environment(ReminderStore())
}
