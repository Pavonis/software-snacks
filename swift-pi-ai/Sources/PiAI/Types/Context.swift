// Conversation context passed to model providers.

/// The full context for a model invocation.
public struct Context: Sendable {
    public var systemPrompt: String?
    public var messages: [Message]
    public var tools: [Tool]

    public init(
        systemPrompt: String? = nil,
        messages: [Message] = [],
        tools: [Tool] = []
    ) {
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.tools = tools
    }
}
