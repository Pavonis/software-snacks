import Foundation
import FoundationModels

// MARK: - LLM Extraction Output Types

/// The complete extraction result from processing a note
@Generable
struct NoteExtraction: Equatable {
    @Guide(description: "People mentioned in the note, including the main subject and anyone else referenced")
    var mentions: [PersonMention]

    @Guide(description: "Specific contact field updates that should be applied (phone, email, address, etc.)")
    var contactUpdates: [ContactUpdate]

    @Guide(description: "Relationships between people mentioned in the note")
    var relationships: [RelationshipMention]

    @Guide(description: "Events, dates, or time-based information mentioned")
    var events: [EventMention]
}

/// A person mentioned in the note
@Generable
struct PersonMention: Equatable, Identifiable {
    var id: String { name }

    @Guide(description: "The person's name as mentioned in the note")
    var name: String

    @Guide(description: "Any contextual clues about who this person is (e.g., 'from work', 'my cousin')")
    var context: String
}

/// A contact field update to apply
@Generable
struct ContactUpdate: Equatable, Identifiable {
    var id: String { "\(personName)-\(field)" }

    @Guide(description: "Name of the person whose contact should be updated")
    var personName: String

    @Guide(description: "The contact field to update", .anyOf([
        "phone",
        "email",
        "address",
        "birthday",
        "jobTitle",
        "company",
        "nickname",
        "note"
    ]))
    var field: String

    @Guide(description: "The new value for this field")
    var value: String
}

/// A relationship between two people
@Generable
struct RelationshipMention: Equatable, Identifiable {
    var id: String { "\(fromPerson)-\(type)-\(toPerson)" }

    @Guide(description: "The first person in the relationship")
    var fromPerson: String

    @Guide(description: "The second person in the relationship")
    var toPerson: String

    @Guide(description: "The type of relationship", .anyOf([
        "spouse",
        "partner",
        "parent",
        "child",
        "sibling",
        "friend",
        "colleague",
        "manager",
        "assistant",
        "relative",
        "engaged",
        "dating"
    ]))
    var type: String
}

/// A time-based event mentioned in the note
@Generable
struct EventMention: Equatable, Identifiable {
    var id: String { "\(title)-\(dateDescription)" }

    @Guide(description: "Brief title or description of the event")
    var title: String

    @Guide(description: "The date or time reference as mentioned (e.g., 'next Tuesday', 'September 2025', 'yesterday')")
    var dateDescription: String

    @Guide(description: "People involved in this event")
    var involvedPeople: [String]
}
