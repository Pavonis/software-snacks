import SwiftUI

/// Root view providing NavigationSplitView with sidebar + detail.
struct ContentView: View {
    @Environment(ReminderStore.self) private var store

    @State private var selectedSmartList: SmartList?
    @State private var selectedList: ReminderList?
    @State private var showingSearch = false
    @State private var showingNewList = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            switch store.authStatus {
            case .fullAccess:
                mainContent
            case .notDetermined:
                requestAccessView
            default:
                deniedAccessView
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedSmartList: $selectedSmartList,
                selectedList: $selectedList,
                showingNewList: $showingNewList
            )
        } detail: {
            detailView
        }
        .searchable(text: .constant(""), placement: .sidebar, prompt: "Search")
        .sheet(isPresented: $showingNewList) {
            ListEditorView(mode: .create)
        }
        .overlay {
            if showingSearch {
                SearchView(isPresented: $showingSearch)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let smartList = selectedSmartList {
            ReminderListView(source: .smart(smartList))
        } else if let list = selectedList {
            ReminderListView(source: .list(list))
        } else {
            ContentUnavailableView(
                "Select a List",
                systemImage: "checklist",
                description: Text("Choose a list from the sidebar to view reminders.")
            )
        }
    }

    // MARK: - Authorization Views

    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Reminders++")
                .font(.largeTitle.bold())

            Text("Reminders++ needs access to your reminders to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Allow Access to Reminders") {
                Task {
                    _ = await store.requestAccess()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 72))
                .foregroundStyle(.orange)

            Text("Access Denied")
                .font(.largeTitle.bold())

            Text("Reminders++ requires access to your reminders. Please enable access in Settings > Privacy & Security > Reminders.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environment(ReminderStore())
}
