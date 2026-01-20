import Foundation

struct Note: Identifiable {
    let id: UUID
    let text: String
    let createdAt: Date
    var extraction: NoteExtraction?
    var isProcessed: Bool { extraction != nil }

    init(id: UUID = UUID(), text: String, createdAt: Date = Date(), extraction: NoteExtraction? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.extraction = extraction
    }
}
