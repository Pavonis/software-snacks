// Streaming events emitted during model response generation.
// Mirrors pi-ai's AssistantMessageEvent protocol.

/// Events emitted during streaming of an assistant message.
///
/// Contract: `start` is emitted before partial updates,
/// and the stream terminates with either `done` or `error`.
public enum AssistantMessageEvent: Sendable {
    // Lifecycle
    case start(partial: AssistantMessage)
    case done(reason: StopReason, message: AssistantMessage)
    case error(reason: StopReason, message: AssistantMessage)

    // Text content streaming
    case textStart(contentIndex: Int, partial: AssistantMessage)
    case textDelta(contentIndex: Int, delta: String, partial: AssistantMessage)
    case textEnd(contentIndex: Int, content: String, partial: AssistantMessage)

    // Thinking/reasoning streaming
    case thinkingStart(contentIndex: Int, partial: AssistantMessage)
    case thinkingDelta(contentIndex: Int, delta: String, partial: AssistantMessage)
    case thinkingEnd(contentIndex: Int, content: String, partial: AssistantMessage)

    // Tool call streaming
    case toolCallStart(contentIndex: Int, partial: AssistantMessage)
    case toolCallDelta(contentIndex: Int, delta: String, partial: AssistantMessage)
    case toolCallEnd(contentIndex: Int, toolCall: ToolCall, partial: AssistantMessage)
}

extension AssistantMessageEvent {
    /// The partial or final message carried by this event.
    public var message: AssistantMessage {
        switch self {
        case .start(let m), .done(_, let m), .error(_, let m),
             .textStart(_, let m), .textDelta(_, _, let m), .textEnd(_, _, let m),
             .thinkingStart(_, let m), .thinkingDelta(_, _, let m), .thinkingEnd(_, _, let m),
             .toolCallStart(_, let m), .toolCallDelta(_, _, let m), .toolCallEnd(_, _, let m):
            return m
        }
    }

    /// Whether this event terminates the stream.
    public var isTerminal: Bool {
        switch self {
        case .done, .error: return true
        default: return false
        }
    }
}
