import Foundation
import Contacts

/// A wrapper around CNContact with additional app-specific enrichment
struct AppContact: Identifiable {
    let id: String
    let cnContact: CNContact

    // Enriched data from notes
    var relationships: [StoredRelationship]
    var events: [StoredEvent]
    var noteHistory: [UUID] // References to Note IDs

    var displayName: String {
        CNContactFormatter.string(from: cnContact, style: .fullName) ?? "Unknown"
    }

    var givenName: String { cnContact.givenName }
    var familyName: String { cnContact.familyName }
    var nickname: String { cnContact.nickname }

    var phoneNumbers: [String] {
        cnContact.phoneNumbers.map { $0.value.stringValue }
    }

    var emailAddresses: [String] {
        cnContact.emailAddresses.map { $0.value as String }
    }

    var jobTitle: String { cnContact.jobTitle }
    var organizationName: String { cnContact.organizationName }

    init(cnContact: CNContact, relationships: [StoredRelationship] = [], events: [StoredEvent] = [], noteHistory: [UUID] = []) {
        self.id = cnContact.identifier
        self.cnContact = cnContact
        self.relationships = relationships
        self.events = events
        self.noteHistory = noteHistory
    }
}

/// A stored relationship between contacts
struct StoredRelationship: Identifiable, Equatable {
    let id: UUID
    let relatedContactId: String
    let relatedContactName: String
    let type: String
    let sourceNoteId: UUID
    let createdAt: Date

    init(id: UUID = UUID(), relatedContactId: String, relatedContactName: String, type: String, sourceNoteId: UUID, createdAt: Date = Date()) {
        self.id = id
        self.relatedContactId = relatedContactId
        self.relatedContactName = relatedContactName
        self.type = type
        self.sourceNoteId = sourceNoteId
        self.createdAt = createdAt
    }
}

/// A stored event associated with contacts
struct StoredEvent: Identifiable, Equatable {
    let id: UUID
    let title: String
    let dateDescription: String
    let sourceNoteId: UUID
    let createdAt: Date

    init(id: UUID = UUID(), title: String, dateDescription: String, sourceNoteId: UUID, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.dateDescription = dateDescription
        self.sourceNoteId = sourceNoteId
        self.createdAt = createdAt
    }
}

// MARK: - Contact Matching

extension AppContact {
    /// Check if this contact matches a name mention (fuzzy matching)
    func matches(name: String) -> Bool {
        let lowercasedName = name.lowercased()
        let fullName = displayName.lowercased()

        // Exact match
        if fullName == lowercasedName { return true }

        // First name match
        if givenName.lowercased() == lowercasedName { return true }

        // Nickname match
        if !nickname.isEmpty && nickname.lowercased() == lowercasedName { return true }

        // Contains match (for partial names like "Mike" matching "Michael")
        if fullName.contains(lowercasedName) || lowercasedName.contains(fullName) { return true }

        return false
    }
}
