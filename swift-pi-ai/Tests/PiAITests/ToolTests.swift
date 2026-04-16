import Testing
@testable import PiAI
import Foundation

// A test tool for unit tests
struct UppercaseTool: ExecutableTool {
    static let toolDefinition = Tool(
        name: "uppercase",
        description: "Convert text to uppercase",
        parameters: .object(
            properties: ["text": .string(description: "The text to uppercase")],
            required: ["text"]
        )
    )

    func execute(arguments: [String: JSONValue]) async throws -> ToolOutput {
        let text = arguments["text"]?.stringValue ?? ""
        return .text(text.uppercased())
    }
}

struct FailingTool: ExecutableTool {
    static let toolDefinition = Tool(
        name: "failing",
        description: "A tool that always fails",
        parameters: .object(properties: [:])
    )

    func execute(arguments: [String: JSONValue]) async throws -> ToolOutput {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Intentional failure"])
    }
}

@Suite("Tool Registry")
struct ToolRegistryTests {
    @Test func registerAndListTools() {
        let registry = ToolRegistry()
        registry.register(UppercaseTool())

        let defs = registry.definitions
        #expect(defs.count == 1)
        #expect(defs[0].name == "uppercase")
    }

    @Test func executeKnownTool() async {
        let registry = ToolRegistry()
        registry.register(UppercaseTool())

        let call = ToolCall(id: "1", name: "uppercase", arguments: ["text": "hello"])
        let result = await registry.execute(call)

        #expect(!result.isError)
        if case .text(let t) = result.content.first {
            #expect(t.text == "HELLO")
        }
    }

    @Test func executeUnknownTool() async {
        let registry = ToolRegistry()
        let call = ToolCall(id: "1", name: "nonexistent", arguments: [:])
        let result = await registry.execute(call)

        #expect(result.isError)
    }

    @Test func executeFailingTool() async {
        let registry = ToolRegistry()
        registry.register(FailingTool())

        let call = ToolCall(id: "1", name: "failing", arguments: [:])
        let result = await registry.execute(call)

        #expect(result.isError)
    }

    @Test func executeAllInParallel() async {
        let registry = ToolRegistry()
        registry.register(UppercaseTool())

        let calls = [
            ToolCall(id: "1", name: "uppercase", arguments: ["text": "hello"]),
            ToolCall(id: "2", name: "uppercase", arguments: ["text": "world"]),
        ]
        let results = await registry.executeAll(calls)

        #expect(results.count == 2)
        // Results should be in order
        #expect(results[0].toolCallId == "1")
        #expect(results[1].toolCallId == "2")
    }
}
