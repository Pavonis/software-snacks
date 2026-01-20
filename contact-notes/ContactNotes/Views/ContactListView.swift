import SwiftUI

struct ContactListView: View {
    @EnvironmentObject var contactsManager: ContactsManager

    @State private var searchText = ""
    @State private var selectedContact: AppContact?

    var filteredContacts: [AppContact] {
        if searchText.isEmpty {
            return contactsManager.contacts
        }
        return contactsManager.contacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Contacts that have enriched data from notes
    var enrichedContacts: [AppContact] {
        filteredContacts.filter { !$0.relationships.isEmpty || !$0.events.isEmpty }
    }

    var regularContacts: [AppContact] {
        filteredContacts.filter { $0.relationships.isEmpty && $0.events.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                if !enrichedContacts.isEmpty {
                    Section("With Notes") {
                        ForEach(enrichedContacts) { contact in
                            ContactRow(contact: contact)
                                .onTapGesture {
                                    selectedContact = contact
                                }
                        }
                    }
                }

                Section(enrichedContacts.isEmpty ? "All Contacts" : "Other Contacts") {
                    ForEach(regularContacts) { contact in
                        ContactRow(contact: contact)
                            .onTapGesture {
                                selectedContact = contact
                            }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Contacts")
            .refreshable {
                await contactsManager.fetchContacts()
            }
            .overlay {
                if contactsManager.contacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Your contacts will appear here.")
                    )
                }
            }
            .sheet(item: $selectedContact) { contact in
                ContactDetailView(contact: contact)
            }
        }
    }
}

struct ContactRow: View {
    let contact: AppContact

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(.blue.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(contact.displayName.prefix(1))
                        .font(.headline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body)

                if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Enrichment indicators
            HStack(spacing: 8) {
                if !contact.relationships.isEmpty {
                    Label("\(contact.relationships.count)", systemImage: "figure.2")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if !contact.events.isEmpty {
                    Label("\(contact.events.count)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ContactListView()
        .environmentObject(ContactsManager())
}
