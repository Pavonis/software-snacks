import Foundation
import Contacts
import SwiftUI

/// Result of applying an extraction to contacts
struct ApplyResult {
    var successfulUpdates: [ContactUpdate] = []
    var failedUpdates: [(ContactUpdate, Error)] = []
    var createdContacts: [String] = []
    var failedCreations: [(String, Error)] = []
    var syncedRelationships: [RelationshipMention] = []
    var failedRelationships: [(RelationshipMention, Error)] = []

    var hasErrors: Bool {
        !failedUpdates.isEmpty || !failedCreations.isEmpty || !failedRelationships.isEmpty
    }

    var errorSummary: String {
        var messages: [String] = []
        for (update, error) in failedUpdates {
            messages.append("Failed to update \(update.personName)'s \(update.field): \(error.localizedDescription)")
        }
        for (name, error) in failedCreations {
            messages.append("Failed to create contact '\(name)': \(error.localizedDescription)")
        }
        for (rel, error) in failedRelationships {
            messages.append("Failed to sync relationship \(rel.fromPerson) → \(rel.toPerson): \(error.localizedDescription)")
        }
        return messages.joined(separator: "\n")
    }
}

@MainActor
class ContactsManager: ObservableObject {
    @Published var authorizationStatus: CNAuthorizationStatus
    @Published var contacts: [AppContact] = []
    @Published var notes: [Note] = []
    @Published var lastApplyResult: ApplyResult?

    private let store = CNContactStore()

    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactRelationsKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    var hasAccess: Bool {
        authorizationStatus == .authorized
    }

    init() {
        self.authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            authorizationStatus = granted ? .authorized : .denied
            if granted {
                await fetchContacts()
            }
        } catch {
            print("Failed to request contacts authorization: \(error)")
            authorizationStatus = .denied
        }
    }

    // MARK: - Fetching Contacts

    func fetchContacts() async {
        guard hasAccess else { return }

        var fetchedContacts: [AppContact] = []
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let appContact = AppContact(cnContact: contact)
                fetchedContacts.append(appContact)
            }
            self.contacts = fetchedContacts
        } catch {
            print("Failed to fetch contacts: \(error)")
        }
    }

    // MARK: - Contact Matching

    func findMatchingContacts(for name: String) -> [AppContact] {
        contacts.filter { $0.matches(name: name) }
    }

    func findBestMatch(for name: String) -> AppContact? {
        let matches = findMatchingContacts(for: name)
        // Return exact match first, otherwise first partial match
        return matches.first { $0.displayName.lowercased() == name.lowercased() }
            ?? matches.first { $0.givenName.lowercased() == name.lowercased() }
            ?? matches.first
    }

    // MARK: - Contact Updates

    func applyUpdate(_ update: ContactUpdate) async throws {
        guard let appContact = findBestMatch(for: update.personName) else {
            throw ContactUpdateError.contactNotFound(update.personName)
        }

        guard let mutableContact = appContact.cnContact.mutableCopy() as? CNMutableContact else {
            throw ContactUpdateError.cannotModify
        }

        switch update.field {
        case "phone":
            let phoneNumber = CNPhoneNumber(stringValue: update.value)
            mutableContact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneNumber))

        case "email":
            mutableContact.emailAddresses.append(CNLabeledValue(label: CNLabelHome, value: update.value as NSString))

        case "address":
            let address = CNMutablePostalAddress()
            address.street = update.value
            mutableContact.postalAddresses.append(CNLabeledValue(label: CNLabelHome, value: address))

        case "jobTitle":
            mutableContact.jobTitle = update.value

        case "company":
            mutableContact.organizationName = update.value

        case "nickname":
            mutableContact.nickname = update.value

        case "note":
            let existingNote = mutableContact.note
            mutableContact.note = existingNote.isEmpty ? update.value : "\(existingNote)\n\(update.value)"

        case "birthday":
            // Parse simple date formats
            if let date = parseDate(update.value) {
                mutableContact.birthday = Calendar.current.dateComponents([.year, .month, .day], from: date)
            }

        default:
            throw ContactUpdateError.unsupportedField(update.field)
        }

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)

        try store.execute(saveRequest)

        // Refresh contacts list
        await fetchContacts()
    }

    // MARK: - Create New Contacts

    func createContact(name: String, context: String? = nil) async throws -> AppContact {
        let mutableContact = CNMutableContact()

        // Parse name into components
        let nameParts = name.split(separator: " ", maxSplits: 1)
        mutableContact.givenName = String(nameParts.first ?? "")
        if nameParts.count > 1 {
            mutableContact.familyName = String(nameParts[1])
        }

        // Add context as a note if provided
        if let context = context, !context.isEmpty {
            mutableContact.note = "Context: \(context)"
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(mutableContact, toContainerWithIdentifier: nil)

        try store.execute(saveRequest)

        // Refresh contacts and find the newly created one
        await fetchContacts()

        guard let newContact = findBestMatch(for: name) else {
            throw ContactUpdateError.contactNotFound(name)
        }

        return newContact
    }

    // MARK: - Sync Relationships to CNContact

    func syncRelationshipToCNContact(_ relationship: RelationshipMention) async throws {
        // Find both contacts
        guard let fromContact = findBestMatch(for: relationship.fromPerson) else {
            throw ContactUpdateError.contactNotFound(relationship.fromPerson)
        }

        guard let toContact = findBestMatch(for: relationship.toPerson) else {
            throw ContactUpdateError.contactNotFound(relationship.toPerson)
        }

        // Update the "from" contact with the relationship
        try await addCNContactRelation(
            to: fromContact,
            relatedName: toContact.displayName,
            relationType: relationship.type
        )

        // Add inverse relationship to the "to" contact
        let inverseType = inverseRelationshipType(relationship.type)
        try await addCNContactRelation(
            to: toContact,
            relatedName: fromContact.displayName,
            relationType: inverseType
        )
    }

    private func addCNContactRelation(to appContact: AppContact, relatedName: String, relationType: String) async throws {
        guard let mutableContact = appContact.cnContact.mutableCopy() as? CNMutableContact else {
            throw ContactUpdateError.cannotModify
        }

        // Check if this relationship already exists
        let existingRelation = mutableContact.contactRelations.first { relation in
            relation.value.name == relatedName
        }

        if existingRelation != nil {
            // Relationship already exists, skip
            return
        }

        // Map our relationship types to CNLabelContactRelation labels
        let label = cnLabelForRelationType(relationType)
        let relation = CNContactRelation(name: relatedName)
        mutableContact.contactRelations.append(CNLabeledValue(label: label, value: relation))

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)

        try store.execute(saveRequest)
    }

    private func cnLabelForRelationType(_ type: String) -> String {
        switch type {
        case "spouse": return CNLabelContactRelationSpouse
        case "partner": return CNLabelContactRelationPartner
        case "parent": return CNLabelContactRelationParent
        case "child": return CNLabelContactRelationChild
        case "sibling": return CNLabelContactRelationSibling
        case "friend": return CNLabelContactRelationFriend
        case "colleague": return CNLabelContactRelationColleague
        case "manager": return CNLabelContactRelationManager
        case "assistant": return CNLabelContactRelationAssistant
        case "engaged": return CNLabelContactRelationPartner
        case "dating": return CNLabelContactRelationPartner
        default: return CNLabelOther
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MMMM d, yyyy",
            "MMMM d"
        ].map { format -> DateFormatter in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter
        }

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    // MARK: - Note Management

    func addNote(_ note: Note) {
        notes.insert(note, at: 0)
    }

    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        }
    }

    // MARK: - Relationship Management

    func addRelationship(from extraction: RelationshipMention, sourceNoteId: UUID) {
        guard let fromContact = findBestMatch(for: extraction.fromPerson),
              let toContact = findBestMatch(for: extraction.toPerson) else {
            return
        }

        // Add relationship to source contact
        if let index = contacts.firstIndex(where: { $0.id == fromContact.id }) {
            let relationship = StoredRelationship(
                relatedContactId: toContact.id,
                relatedContactName: toContact.displayName,
                type: extraction.type,
                sourceNoteId: sourceNoteId
            )
            contacts[index].relationships.append(relationship)
        }

        // Add inverse relationship to target contact
        if let index = contacts.firstIndex(where: { $0.id == toContact.id }) {
            let inverseType = inverseRelationshipType(extraction.type)
            let relationship = StoredRelationship(
                relatedContactId: fromContact.id,
                relatedContactName: fromContact.displayName,
                type: inverseType,
                sourceNoteId: sourceNoteId
            )
            contacts[index].relationships.append(relationship)
        }
    }

    private func inverseRelationshipType(_ type: String) -> String {
        switch type {
        case "parent": return "child"
        case "child": return "parent"
        case "manager": return "assistant"
        case "assistant": return "manager"
        default: return type // symmetric relationships
        }
    }

    // MARK: - Event Management

    func addEvent(from extraction: EventMention, sourceNoteId: UUID) {
        let event = StoredEvent(
            title: extraction.title,
            dateDescription: extraction.dateDescription,
            sourceNoteId: sourceNoteId
        )

        // Link event to involved contacts
        for personName in extraction.involvedPeople {
            if let contact = findBestMatch(for: personName),
               let index = contacts.firstIndex(where: { $0.id == contact.id }) {
                contacts[index].events.append(event)
            }
        }
    }
}

// MARK: - Errors

enum ContactUpdateError: LocalizedError {
    case contactNotFound(String)
    case cannotModify
    case unsupportedField(String)

    var errorDescription: String? {
        switch self {
        case .contactNotFound(let name):
            return "Could not find contact matching '\(name)'"
        case .cannotModify:
            return "Cannot modify this contact"
        case .unsupportedField(let field):
            return "Unsupported field: \(field)"
        }
    }
}
