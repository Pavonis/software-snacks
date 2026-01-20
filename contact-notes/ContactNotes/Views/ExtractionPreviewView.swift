import SwiftUI

struct ExtractionPreviewView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var noteProcessor: NoteProcessor
    @Environment(\.dismiss) private var dismiss

    let note: Note
    let onSave: () -> Void

    @State private var isApplying = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Original note
                    NoteSection(title: "Original Note", icon: "text.quote") {
                        Text(note.text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let extraction = note.extraction {
                        // People mentioned
                        if !extraction.mentions.isEmpty {
                            NoteSection(title: "People Mentioned", icon: "person.2") {
                                ForEach(extraction.mentions) { mention in
                                    PersonMentionRow(mention: mention)
                                }
                            }
                        }

                        // Contact updates
                        if !extraction.contactUpdates.isEmpty {
                            NoteSection(title: "Contact Updates", icon: "pencil") {
                                ForEach(extraction.contactUpdates) { update in
                                    ContactUpdateRow(update: update)
                                }
                            }
                        }

                        // Relationships
                        if !extraction.relationships.isEmpty {
                            NoteSection(title: "Relationships", icon: "figure.2") {
                                ForEach(extraction.relationships) { relationship in
                                    RelationshipRow(relationship: relationship)
                                }
                            }
                        }

                        // Events
                        if !extraction.events.isEmpty {
                            NoteSection(title: "Events", icon: "calendar") {
                                ForEach(extraction.events) { event in
                                    EventRow(event: event)
                                }
                            }
                        }

                        // Empty state
                        if extraction.mentions.isEmpty
                            && extraction.contactUpdates.isEmpty
                            && extraction.relationships.isEmpty
                            && extraction.events.isEmpty {
                            ContentUnavailableView(
                                "No Information Extracted",
                                systemImage: "questionmark.circle",
                                description: Text("The note didn't contain any recognizable contact information.")
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Review Extraction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await applyAndSave()
                        }
                    } label: {
                        if isApplying {
                            ProgressView()
                        } else {
                            Text("Save & Apply")
                        }
                    }
                    .disabled(isApplying)
                }
            }
        }
    }

    private func applyAndSave() async {
        guard let extraction = note.extraction else {
            dismiss()
            return
        }

        isApplying = true

        // Apply extraction to contacts
        await noteProcessor.apply(
            extraction: extraction,
            to: contactsManager,
            noteId: note.id
        )

        // Save the note
        contactsManager.addNote(note)

        isApplying = false
        onSave()
        dismiss()
    }
}

// MARK: - Section Container

struct NoteSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Row Components

struct PersonMentionRow: View {
    let mention: PersonMention
    @EnvironmentObject var contactsManager: ContactsManager

    var matchedContact: AppContact? {
        contactsManager.findBestMatch(for: mention.name)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(mention.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !mention.context.isEmpty {
                    Text(mention.context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let contact = matchedContact {
                Label(contact.displayName, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("New contact", systemImage: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct ContactUpdateRow: View {
    let update: ContactUpdate
    @EnvironmentObject var contactsManager: ContactsManager

    var hasMatch: Bool {
        contactsManager.findBestMatch(for: update.personName) != nil
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(update.personName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text(update.field.capitalized + ":")
                        .foregroundStyle(.secondary)
                    Text(update.value)
                }
                .font(.caption)
            }

            Spacer()

            Image(systemName: hasMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(hasMatch ? .green : .orange)
        }
    }
}

struct RelationshipRow: View {
    let relationship: RelationshipMention

    var body: some View {
        HStack {
            Text(relationship.fromPerson)
                .font(.subheadline)
                .fontWeight(.medium)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(relationship.type)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.2))
                .clipShape(Capsule())

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(relationship.toPerson)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct EventRow: View {
    let event: EventMention

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Label(event.dateDescription, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !event.involvedPeople.isEmpty {
                    Text("with \(event.involvedPeople.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    let note = Note(
        text: "Had lunch with Sarah. She mentioned her daughter Emma is starting school in September. Her new phone is 555-1234.",
        extraction: NoteExtraction(
            mentions: [
                PersonMention(name: "Sarah", context: "friend"),
                PersonMention(name: "Emma", context: "Sarah's daughter")
            ],
            contactUpdates: [
                ContactUpdate(personName: "Sarah", field: "phone", value: "555-1234")
            ],
            relationships: [
                RelationshipMention(fromPerson: "Sarah", toPerson: "Emma", type: "parent")
            ],
            events: [
                EventMention(title: "Emma starting school", dateDescription: "September", involvedPeople: ["Emma"])
            ]
        )
    )

    return ExtractionPreviewView(note: note) {}
        .environmentObject(ContactsManager())
        .environmentObject(NoteProcessor())
}
