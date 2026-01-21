import Foundation
import FoundationModels

@MainActor
class NoteProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: Error?
    @Published var isAvailable = false

    private var session: LanguageModelSession?

    init() {
        Task {
            await checkAvailability()
        }
    }

    // MARK: - Availability

    func checkAvailability() async {
        do {
            // Check if Foundation Models is available on this device
            let availability = SystemLanguageModel.default.availability
            switch availability {
            case .available:
                session = LanguageModelSession()
                isAvailable = true
            case .unavailable:
                isAvailable = false
            @unknown default:
                isAvailable = false
            }
        }
    }

    // MARK: - Note Processing

    func process(noteText: String) async throws -> NoteExtraction {
        guard let session = session else {
            throw ProcessingError.modelUnavailable
        }

        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        let prompt = """
        Analyze this personal note about contacts and extract structured information.

        Note:
        \(noteText)

        Extract:
        - People mentioned (with any contextual clues about who they are)
        - Contact information updates (new phone numbers, emails, addresses, job changes, etc.)
        - Relationships between people (family, work, romantic, etc.)
        - Events or dates mentioned (upcoming occasions, past events, milestones)

        Only include information that is explicitly stated or strongly implied in the note.
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: NoteExtraction.self
            )
            return response.content
        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - Apply Extraction

    func apply(extraction: NoteExtraction, to contactsManager: ContactsManager, noteId: UUID) async -> ApplyResult {
        var result = ApplyResult()

        // First, create any new contacts for unmatched mentions
        for mention in extraction.mentions {
            if contactsManager.findBestMatch(for: mention.name) == nil {
                do {
                    _ = try await contactsManager.createContact(name: mention.name, context: mention.context)
                    result.createdContacts.append(mention.name)
                } catch {
                    result.failedCreations.append((mention.name, error))
                }
            }
        }

        // Apply contact updates
        for update in extraction.contactUpdates {
            do {
                try await contactsManager.applyUpdate(update)
                result.successfulUpdates.append(update)
            } catch {
                result.failedUpdates.append((update, error))
            }
        }

        // Sync relationships to CNContact and store in-memory
        for relationship in extraction.relationships {
            // First sync to CNContact's contactRelations field
            do {
                try await contactsManager.syncRelationshipToCNContact(relationship)
                result.syncedRelationships.append(relationship)
            } catch {
                result.failedRelationships.append((relationship, error))
            }

            // Also store in our in-memory model for the app's relationship graph
            contactsManager.addRelationship(from: relationship, sourceNoteId: noteId)
        }

        // Store events
        for event in extraction.events {
            contactsManager.addEvent(from: event, sourceNoteId: noteId)
        }

        // Store the result for UI access
        contactsManager.lastApplyResult = result

        return result
    }
}

// MARK: - Errors

enum ProcessingError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device"
        }
    }
}
