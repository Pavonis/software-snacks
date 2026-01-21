import Foundation
import Contacts
import SwiftUI

@MainActor
class ContactsManager: ObservableObject {
    @Published var authorizationStatus: CNAuthorizationStatus
    @Published var contacts: [AppContact] = []
    @Published var notes: [Note] = []

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
        // CNContactNoteKey as CNKeyDescriptor,
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
