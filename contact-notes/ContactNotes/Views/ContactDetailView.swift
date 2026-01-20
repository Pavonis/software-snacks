import SwiftUI

struct ContactDetailView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss

    let contact: AppContact

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Circle()
                            .fill(.blue.gradient)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Text(contact.displayName.prefix(1))
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }

                        Text(contact.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if !contact.jobTitle.isEmpty || !contact.organizationName.isEmpty {
                            Text([contact.jobTitle, contact.organizationName]
                                .filter { !$0.isEmpty }
                                .joined(separator: " at "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top)

                    // Contact Info
                    if !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty {
                        DetailSection(title: "Contact Info", icon: "info.circle") {
                            ForEach(contact.phoneNumbers, id: \.self) { phone in
                                DetailRow(label: "Phone", value: phone, icon: "phone")
                            }

                            ForEach(contact.emailAddresses, id: \.self) { email in
                                DetailRow(label: "Email", value: email, icon: "envelope")
                            }
                        }
                    }

                    // Relationships
                    if !contact.relationships.isEmpty {
                        DetailSection(title: "Relationships", icon: "figure.2") {
                            ForEach(contact.relationships) { relationship in
                                HStack {
                                    Text(relationship.type.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.blue.opacity(0.2))
                                        .clipShape(Capsule())

                                    Text(relationship.relatedContactName)
                                        .font(.subheadline)

                                    Spacer()
                                }
                            }
                        }
                    }

                    // Events
                    if !contact.events.isEmpty {
                        DetailSection(title: "Events", icon: "calendar") {
                            ForEach(contact.events) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(event.dateDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Related Notes
                    if !contact.noteHistory.isEmpty {
                        let relatedNotes = contactsManager.notes.filter {
                            contact.noteHistory.contains($0.id)
                        }

                        if !relatedNotes.isEmpty {
                            DetailSection(title: "Related Notes", icon: "note.text") {
                                ForEach(relatedNotes) { note in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(note.text)
                                            .font(.subheadline)
                                            .lineLimit(2)

                                        Text(note.createdAt, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
            }

            Spacer()
        }
    }
}

#Preview {
    ContactDetailView(
        contact: AppContact(
            cnContact: {
                let contact = CNMutableContact()
                contact.givenName = "Sarah"
                contact.familyName = "Johnson"
                contact.organizationName = "Apple"
                contact.jobTitle = "Engineer"
                return contact
            }(),
            relationships: [
                StoredRelationship(
                    relatedContactId: "123",
                    relatedContactName: "Emma Johnson",
                    type: "child",
                    sourceNoteId: UUID()
                )
            ],
            events: [
                StoredEvent(
                    title: "Emma starting school",
                    dateDescription: "September 2025",
                    sourceNoteId: UUID()
                )
            ]
        )
    )
    .environmentObject(ContactsManager())
}

import Contacts
