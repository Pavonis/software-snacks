// Tool definition and protocol.
//
// Inspired by Apple's Foundation Models @Tool pattern — tools are defined as
// concrete types conforming to a protocol, with parameters described via
// JSON Schema. This gives us type safety at the definition site while remaining
// wire-compatible with every provider.

/// A tool the model can invoke.
public struct Tool: Sendable {
    public var name: String
    public var description: String
    public var parameters: JSONSchema

    public init(name: String, description: String, parameters: JSONSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Protocol for defining executable tools with typed parameters.
///
/// Inspired by Apple's `@Tool` macro — conforming types declare their parameter
/// schema and an async execution method. The framework handles serialization.
///
/// Example:
/// ```swift
/// struct WeatherTool: ExecutableTool {
///     static let toolDefinition = Tool(
///         name: "get_weather",
///         description: "Get the current weather for a location",
///         parameters: .object(properties: [
///             "location": .string(description: "City name"),
///             "unit": .enum(values: ["celsius", "fahrenheit"])
///         ], required: ["location"])
///     )
///
///     func execute(arguments: [String: JSONValue]) async throws -> ToolOutput {
///         let location = arguments["location"]?.stringValue ?? "unknown"
///         return .text("72°F and sunny in \(location)")
///     }
/// }
/// ```
public protocol ExecutableTool: Sendable {
    /// The tool definition including name, description, and parameter schema.
    static var toolDefinition: Tool { get }

    /// Execute the tool with the given arguments.
    func execute(arguments: [String: JSONValue]) async throws -> ToolOutput
}

/// Output from a tool execution.
public enum ToolOutput: Sendable {
    case text(String)
    case blocks([ToolResultContentBlock])

    /// Convert to a ToolResultMessage.
    public func toMessage(toolCallId: String, toolName: String) -> ToolResultMessage {
        switch self {
        case .text(let text):
            return ToolResultMessage(toolCallId: toolCallId, toolName: toolName, text: text)
        case .blocks(let blocks):
            return ToolResultMessage(
                toolCallId: toolCallId, toolName: toolName,
                content: blocks, isError: false
            )
        }
    }
}

/// A registry of executable tools for automatic dispatch.
public final class ToolRegistry: @unchecked Sendable {
    private var tools: [String: any ExecutableTool] = [:]

    public init() {}

    /// Register a tool instance.
    public func register(_ tool: any ExecutableTool) {
        tools[type(of: tool).toolDefinition.name] = tool
    }

    /// Get all tool definitions for passing to a model.
    public var definitions: [Tool] {
        tools.values.map { type(of: $0).toolDefinition }
    }

    /// Execute a tool call, returning a ToolResultMessage.
    public func execute(_ toolCall: ToolCall) async -> ToolResultMessage {
        guard let tool = tools[toolCall.name] else {
            return ToolResultMessage(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                text: "Unknown tool: \(toolCall.name)",
                isError: true
            )
        }

        do {
            let output = try await tool.execute(arguments: toolCall.arguments)
            return output.toMessage(toolCallId: toolCall.id, toolName: toolCall.name)
        } catch {
            return ToolResultMessage(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                text: "Tool error: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    /// Execute all tool calls from an assistant message in parallel.
    public func executeAll(_ toolCalls: [ToolCall]) async -> [ToolResultMessage] {
        await withTaskGroup(of: (Int, ToolResultMessage).self) { group in
            for (index, call) in toolCalls.enumerated() {
                group.addTask {
                    let result = await self.execute(call)
                    return (index, result)
                }
            }

            var results = [(Int, ToolResultMessage)]()
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
