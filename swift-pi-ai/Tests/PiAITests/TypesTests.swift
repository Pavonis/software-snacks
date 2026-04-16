import Testing
@testable import PiAI
import Foundation

@Suite("JSON Value")
struct JSONValueTests {
    @Test func literals() {
        let null: JSONValue = nil
        let bool: JSONValue = true
        let int: JSONValue = 42
        let double: JSONValue = 3.14
        let string: JSONValue = "hello"
        let array: JSONValue = [1, 2, 3]
        let object: JSONValue = ["key": "value"]

        #expect(null.isNull)
        #expect(bool.boolValue == true)
        #expect(int.intValue == 42)
        #expect(double.doubleValue == 3.14)
        #expect(string.stringValue == "hello")
        #expect(array.arrayValue?.count == 3)
        #expect(object["key"]?.stringValue == "value")
    }

    @Test func codableRoundTrip() throws {
        let value: JSONValue = .object([
            "name": "test",
            "count": 5,
            "active": true,
            "tags": .array(["a", "b"]),
            "meta": nil,
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }
}

@Suite("JSON Schema")
struct JSONSchemaTests {
    @Test func objectSchema() {
        let schema = JSONSchema.object(
            properties: [
                "name": .string(description: "User name"),
                "age": .integer(description: "User age"),
            ],
            required: ["name"]
        )

        let json = schema.toJSON()
        #expect(json["type"]?.stringValue == "object")
        #expect(json["required"]?.arrayValue?.count == 1)

        if let props = json["properties"]?.objectValue {
            #expect(props["name"]?["type"]?.stringValue == "string")
            #expect(props["age"]?["type"]?.stringValue == "integer")
        }
    }

    @Test func enumSchema() {
        let schema = JSONSchema.enum(values: ["red", "green", "blue"], description: "Color")
        let json = schema.toJSON()
        #expect(json["type"]?.stringValue == "string")
        #expect(json["enum"]?.arrayValue?.count == 3)
    }
}

@Suite("Messages")
struct MessageTests {
    @Test func userMessagePlainText() {
        let msg = UserMessage("Hello, world!")
        #expect(msg.content.plainText == "Hello, world!")
    }

    @Test func assistantMessageText() {
        let msg = AssistantMessage(
            content: [
                .text(TextContent(text: "Hello ")),
                .text(TextContent(text: "world")),
            ],
            api: "test",
            provider: "test",
            model: "test"
        )
        #expect(msg.text == "Hello world")
    }

    @Test func assistantMessageToolCalls() {
        let tc = ToolCall(id: "1", name: "search", arguments: ["query": "swift"])
        let msg = AssistantMessage(
            content: [
                .text(TextContent(text: "Let me search")),
                .toolCall(tc),
            ],
            api: "test",
            provider: "test",
            model: "test"
        )
        #expect(msg.toolCalls.count == 1)
        #expect(msg.toolCalls[0].name == "search")
    }

    @Test func toolResultConvenience() {
        let result = ToolResultMessage(
            toolCallId: "1",
            toolName: "search",
            text: "Found 5 results"
        )
        #expect(result.content.count == 1)
        #expect(!result.isError)
    }

    @Test func messageCodableRoundTrip() throws {
        let messages: [Message] = [
            .user(UserMessage("Hello")),
            .assistant(AssistantMessage(
                content: [.text(TextContent(text: "Hi there"))],
                api: "test", provider: "test", model: "test"
            )),
            .toolResult(ToolResultMessage(
                toolCallId: "tc1", toolName: "search", text: "results"
            )),
        ]

        let data = try JSONEncoder().encode(messages)
        let decoded = try JSONDecoder().decode([Message].self, from: data)
        #expect(decoded.count == 3)
    }
}

@Suite("Usage")
struct UsageTests {
    @Test func costCalculation() {
        let modelCost = ModelCost(input: 3.0, output: 15.0, cacheRead: 0.3, cacheWrite: 3.75)
        let usage = Usage(input: 1000, output: 500, cacheRead: 200, cacheWrite: 100)
        let cost = modelCost.calculate(from: usage)

        #expect(cost.input == 3.0 / 1_000_000 * 1000)
        #expect(cost.output == 15.0 / 1_000_000 * 500)
        #expect(cost.total > 0)
    }
}
