import SwiftUI
import Contacts

struct ContentView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var noteProcessor: NoteProcessor

    var body: some View {
        Group {
            switch contactsManager.authorizationStatus {
            case .authorized, .limited:
                MainTabView()
            case .notDetermined:
                AuthorizationRequestView()
            case .denied, .restricted:
                AccessDeniedView()
            @unknown default:
                AuthorizationRequestView()
            }
        }
        .task {
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }
}

// MARK: - Authorization Request

struct AuthorizationRequestView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var noteProcessor: NoteProcessor

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Contact Notes")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Write notes about your contacts and let AI extract updates, relationships, and events automatically.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                FeatureRow(icon: "square.and.pencil", text: "Write natural language notes")
                FeatureRow(icon: "cpu", text: "On-device AI processing")
                FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Sync to your contacts")
                FeatureRow(icon: "figure.2", text: "Track relationships")
            }
            .padding(.vertical)

            if !noteProcessor.isAvailable {
                Label("Apple Intelligence required", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Button {
                Task {
                    await contactsManager.requestAuthorization()
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Access Denied

struct AccessDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Contacts Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Contact Notes needs access to your contacts to sync updates and track relationships.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            NoteEntryView()
                .tabItem {
                    Label("New Note", systemImage: "square.and.pencil")
                }

            ContactListView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2")
                }

            NoteHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ContactsManager())
        .environmentObject(NoteProcessor())
}
