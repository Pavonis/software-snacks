import SwiftUI

@main
struct RemindersPlusPlusApp: App {
    @State private var store = ReminderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
