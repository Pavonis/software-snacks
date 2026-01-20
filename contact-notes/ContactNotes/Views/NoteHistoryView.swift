import SwiftUI

struct NoteHistoryView: View {
    @EnvironmentObject var contactsManager: ContactsManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(contactsManager.notes) { note in
                    NoteHistoryRow(note: note)
                }
            }
            .navigationTitle("Note History")
            .overlay {
                if contactsManager.notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes Yet",
                        systemImage: "note.text",
                        description: Text("Notes you write will appear here.")
                    )
                }
            }
        }
    }
}

struct NoteHistoryRow: View {
    let note: Note
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(note.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let extraction = note.extraction {
                    HStack(spacing: 8) {
                        if !extraction.mentions.isEmpty {
                            Label("\(extraction.mentions.count)", systemImage: "person")
                        }
                        if !extraction.contactUpdates.isEmpty {
                            Label("\(extraction.contactUpdates.count)", systemImage: "pencil")
                        }
                        if !extraction.relationships.isEmpty {
                            Label("\(extraction.relationships.count)", systemImage: "figure.2")
                        }
                        if !extraction.events.isEmpty {
                            Label("\(extraction.events.count)", systemImage: "calendar")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Note text
            Text(note.text)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)

            // Expand button
            if note.text.count > 150 {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            // Extraction summary when expanded
            if isExpanded, let extraction = note.extraction {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if !extraction.mentions.isEmpty {
                        Label(
                            extraction.mentions.map(\.name).joined(separator: ", "),
                            systemImage: "person.2"
                        )
                        .font(.caption)
                    }

                    if !extraction.relationships.isEmpty {
                        ForEach(extraction.relationships) { rel in
                            Text("\(rel.fromPerson) is \(rel.toPerson)'s \(rel.type)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !extraction.events.isEmpty {
                        ForEach(extraction.events) { event in
                            Label("\(event.title) - \(event.dateDescription)", systemImage: "calendar")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let manager = ContactsManager()
    manager.notes = [
        Note(
            text: "Had coffee with Mike today. He mentioned his wife Sarah is expecting their second child in March. He's also switching jobs to work at Netflix as a senior engineer.",
            extraction: NoteExtraction(
                mentions: [
                    PersonMention(name: "Mike", context: "friend"),
                    PersonMention(name: "Sarah", context: "Mike's wife")
                ],
                contactUpdates: [
                    ContactUpdate(personName: "Mike", field: "company", value: "Netflix"),
                    ContactUpdate(personName: "Mike", field: "jobTitle", value: "Senior Engineer")
                ],
                relationships: [
                    RelationshipMention(fromPerson: "Mike", toPerson: "Sarah", type: "spouse")
                ],
                events: [
                    EventMention(title: "Sarah expecting baby", dateDescription: "March", involvedPeople: ["Mike", "Sarah"])
                ]
            )
        ),
        Note(
            text: "Quick call with mom. Dad's birthday is coming up next week.",
            extraction: NoteExtraction(
                mentions: [
                    PersonMention(name: "Mom", context: "parent"),
                    PersonMention(name: "Dad", context: "parent")
                ],
                contactUpdates: [],
                relationships: [],
                events: [
                    EventMention(title: "Dad's birthday", dateDescription: "next week", involvedPeople: ["Dad"])
                ]
            )
        )
    ]

    return NoteHistoryView()
        .environmentObject(manager)
}
