// Message types that form the conversation model.
// Mirrors pi-ai's UserMessage, AssistantMessage, ToolResultMessage.

import Foundation

/// A message from the user.
public struct UserMessage: Sendable, Codable, Equatable {
    public var content: UserContent
    public var timestamp: Date

    public init(_ text: String, timestamp: Date = .now) {
        self.content = .text(text)
        self.timestamp = timestamp
    }

    public init(blocks: [UserContentBlock], timestamp: Date = .now) {
        self.content = .blocks(blocks)
        self.timestamp = timestamp
    }
}

/// User message content — either a plain string or structured blocks.
public enum UserContent: Sendable, Codable, Equatable {
    case text(String)
    case blocks([UserContentBlock])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .blocks(try container.decode([UserContentBlock].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }

    /// Flatten to plain text (concatenating text blocks, ignoring images).
    public var plainText: String {
        switch self {
        case .text(let s): return s
        case .blocks(let blocks):
            return blocks.compactMap { block in
                if case .text(let t) = block { return t.text }
                return nil
            }.joined(separator: "\n")
        }
    }
}

/// A response from the model.
public struct AssistantMessage: Sendable, Codable, Equatable {
    public var content: [AssistantContentBlock]
    public var api: String
    public var provider: String
    public var model: String
    public var responseId: String?
    public var usage: Usage
    public var stopReason: StopReason
    public var errorMessage: String?
    public var timestamp: Date

    public init(
        content: [AssistantContentBlock] = [],
        api: String,
        provider: String,
        model: String,
        responseId: String? = nil,
        usage: Usage = .zero,
        stopReason: StopReason = .stop,
        errorMessage: String? = nil,
        timestamp: Date = .now
    ) {
        self.content = content
        self.api = api
        self.provider = provider
        self.model = model
        self.responseId = responseId
        self.usage = usage
        self.stopReason = stopReason
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }

    /// Convenience: extract all text from content blocks.
    public var text: String {
        content.compactMap { block in
            if case .text(let t) = block { return t.text }
            return nil
        }.joined()
    }

    /// Convenience: extract all tool calls from content blocks.
    public var toolCalls: [ToolCall] {
        content.compactMap { block in
            if case .toolCall(let tc) = block { return tc }
            return nil
        }
    }

    /// Convenience: extract all thinking blocks from content blocks.
    public var thinkingBlocks: [ThinkingContent] {
        content.compactMap { block in
            if case .thinking(let t) = block { return t }
            return nil
        }
    }
}

/// The result of executing a tool.
public struct ToolResultMessage: Sendable, Codable, Equatable {
    public var toolCallId: String
    public var toolName: String
    public var content: [ToolResultContentBlock]
    public var isError: Bool
    public var timestamp: Date

    public init(
        toolCallId: String,
        toolName: String,
        content: [ToolResultContentBlock],
        isError: Bool = false,
        timestamp: Date = .now
    ) {
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.content = content
        self.isError = isError
        self.timestamp = timestamp
    }

    /// Convenience initializer for a simple text result.
    public init(toolCallId: String, toolName: String, text: String, isError: Bool = false) {
        self.init(
            toolCallId: toolCallId,
            toolName: toolName,
            content: [.text(TextContent(text: text))],
            isError: isError
        )
    }
}

/// A message in a conversation — user, assistant, or tool result.
public enum Message: Sendable, Codable, Equatable {
    case user(UserMessage)
    case assistant(AssistantMessage)
    case toolResult(ToolResultMessage)

    private enum CodingKeys: String, CodingKey {
        case role
    }

    private enum Role: String, Codable {
        case user, assistant, toolResult
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let role = try container.decode(Role.self, forKey: .role)
        switch role {
        case .user:
            self = .user(try UserMessage(from: decoder))
        case .assistant:
            self = .assistant(try AssistantMessage(from: decoder))
        case .toolResult:
            self = .toolResult(try ToolResultMessage(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user(let msg):
            try container.encode(Role.user, forKey: .role)
            try msg.encode(to: encoder)
        case .assistant(let msg):
            try container.encode(Role.assistant, forKey: .role)
            try msg.encode(to: encoder)
        case .toolResult(let msg):
            try container.encode(Role.toolResult, forKey: .role)
            try msg.encode(to: encoder)
        }
    }
}
