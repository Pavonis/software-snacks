import SwiftUI

@main
struct ContactNotesApp: App {
    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var noteProcessor = NoteProcessor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(contactsManager)
                .environmentObject(noteProcessor)
        }
    }
}
