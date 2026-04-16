// Content block types that compose messages.
// Mirrors pi-ai's TextContent, ThinkingContent, ImageContent, and ToolCall.

/// A block of text content in a message.
public struct TextContent: Sendable, Codable, Equatable {
    public var text: String
    public var textSignature: String?

    public init(text: String, textSignature: String? = nil) {
        self.text = text
        self.textSignature = textSignature
    }
}

/// A block of model reasoning/thinking content.
public struct ThinkingContent: Sendable, Codable, Equatable {
    public var thinking: String
    public var thinkingSignature: String?
    /// When true, content was redacted by safety filters. The opaque encrypted
    /// payload lives in `thinkingSignature` for multi-turn continuity.
    public var redacted: Bool

    public init(thinking: String, thinkingSignature: String? = nil, redacted: Bool = false) {
        self.thinking = thinking
        self.thinkingSignature = thinkingSignature
        self.redacted = redacted
    }
}

/// Base64-encoded image content.
public struct ImageContent: Sendable, Codable, Equatable {
    public var data: String
    public var mimeType: String

    public init(data: String, mimeType: String) {
        self.data = data
        self.mimeType = mimeType
    }
}

/// A tool invocation requested by the model.
public struct ToolCall: Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var arguments: [String: JSONValue]
    public var thoughtSignature: String?

    public init(
        id: String,
        name: String,
        arguments: [String: JSONValue] = [:],
        thoughtSignature: String? = nil
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.thoughtSignature = thoughtSignature
    }
}

/// Content that can appear in an assistant message.
public enum AssistantContentBlock: Sendable, Codable, Equatable {
    case text(TextContent)
    case thinking(ThinkingContent)
    case toolCall(ToolCall)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum BlockType: String, Codable {
        case text, thinking, toolCall
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BlockType.self, forKey: .type)
        switch type {
        case .text:
            self = .text(try TextContent(from: decoder))
        case .thinking:
            self = .thinking(try ThinkingContent(from: decoder))
        case .toolCall:
            self = .toolCall(try ToolCall(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let content):
            try container.encode(BlockType.text, forKey: .type)
            try content.encode(to: encoder)
        case .thinking(let content):
            try container.encode(BlockType.thinking, forKey: .type)
            try content.encode(to: encoder)
        case .toolCall(let call):
            try container.encode(BlockType.toolCall, forKey: .type)
            try call.encode(to: encoder)
        }
    }
}

/// Content that can appear in user messages.
public enum UserContentBlock: Sendable, Codable, Equatable {
    case text(TextContent)
    case image(ImageContent)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum BlockType: String, Codable {
        case text, image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BlockType.self, forKey: .type)
        switch type {
        case .text:
            self = .text(try TextContent(from: decoder))
        case .image:
            self = .image(try ImageContent(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let content):
            try container.encode(BlockType.text, forKey: .type)
            try content.encode(to: encoder)
        case .image(let content):
            try container.encode(BlockType.image, forKey: .type)
            try content.encode(to: encoder)
        }
    }
}

/// Content that can appear in tool result messages.
public enum ToolResultContentBlock: Sendable, Codable, Equatable {
    case text(TextContent)
    case image(ImageContent)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum BlockType: String, Codable {
        case text, image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BlockType.self, forKey: .type)
        switch type {
        case .text:
            self = .text(try TextContent(from: decoder))
        case .image:
            self = .image(try ImageContent(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let content):
            try container.encode(BlockType.text, forKey: .type)
            try content.encode(to: encoder)
        case .image(let content):
            try container.encode(BlockType.image, forKey: .type)
            try content.encode(to: encoder)
        }
    }
}
