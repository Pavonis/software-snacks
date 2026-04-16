import Testing
@testable import PiAI
import Foundation

struct MovieReview: Generable, Codable, Equatable {
    static var schema: JSONSchema {
        .object(properties: [
            "title": .string(description: "Movie title"),
            "rating": .integer(description: "Rating from 1 to 5"),
            "summary": .string(description: "Brief review"),
        ], required: ["title", "rating", "summary"])
    }

    let title: String
    let rating: Int
    let summary: String
}

@Suite("Generable / Structured Output")
struct GenerableTests {
    @Test func decodeFromAssistantMessage() throws {
        let json = """
        {"title": "Inception", "rating": 5, "summary": "Mind-bending masterpiece"}
        """
        let msg = AssistantMessage(
            content: [.text(TextContent(text: json))],
            api: "test", provider: "test", model: "test"
        )

        let review = try decodeGenerated(MovieReview.self, from: msg)
        #expect(review.title == "Inception")
        #expect(review.rating == 5)
        #expect(review.summary == "Mind-bending masterpiece")
    }

    @Test func decodeStripsCodeFences() throws {
        let json = """
        ```json
        {"title": "Matrix", "rating": 4, "summary": "Groundbreaking sci-fi"}
        ```
        """
        let msg = AssistantMessage(
            content: [.text(TextContent(text: json))],
            api: "test", provider: "test", model: "test"
        )

        let review = try decodeGenerated(MovieReview.self, from: msg)
        #expect(review.title == "Matrix")
    }

    @Test func decodeFailsOnEmptyText() {
        let msg = AssistantMessage(
            content: [],
            api: "test", provider: "test", model: "test"
        )

        #expect(throws: GenerationError.self) {
            try decodeGenerated(MovieReview.self, from: msg)
        }
    }

    @Test func generateRequestBuildsContext() {
        let request = GenerateRequest<MovieReview>(
            prompt: "Review Inception",
            systemPrompt: "You are a film critic."
        )
        let context = request.buildContext()

        #expect(context.systemPrompt?.contains("film critic") == true)
        #expect(context.systemPrompt?.contains("JSON") == true)
        #expect(context.messages.count == 1)
    }

    @Test func schemaGeneratesValidJSON() {
        let json = MovieReview.schema.toJSON()
        #expect(json["type"]?.stringValue == "object")

        let props = json["properties"]?.objectValue
        #expect(props?["title"]?["type"]?.stringValue == "string")
        #expect(props?["rating"]?["type"]?.stringValue == "integer")

        let required = json["required"]?.arrayValue
        #expect(required?.count == 3)
    }
}
