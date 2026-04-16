// Cross-provider message transformation.
//
// When switching between providers mid-conversation (e.g., starting with
// OpenAI then continuing with Anthropic), messages need to be adapted:
// - Thinking blocks from one provider become text with <thinking> tags for another
// - Redacted thinking is dropped (opaque to other providers)
// - Tool call IDs may need normalization
// - Orphaned tool calls get synthetic error results
// - Error/aborted messages are skipped

/// Transform a message history for use with a target model.
///
/// This handles the cross-provider compatibility issues that arise when
/// a conversation includes messages from multiple providers.
public func transformMessages(
    _ messages: [Message],
    for targetModel: Model
) -> [Message] {
    var result: [Message] = []
    var pendingToolCalls: [String: ToolCall] = [:] // id -> tool call

    for message in messages {
        switch message {
        case .user:
            result.append(message)

        case .assistant(let assistantMsg):
            // Skip error/aborted messages — they represent incomplete turns
            if assistantMsg.stopReason == .error || assistantMsg.stopReason == .aborted {
                continue
            }

            let sameProvider = assistantMsg.provider == targetModel.provider

            var transformedContent: [AssistantContentBlock] = []
            for block in assistantMsg.content {
                switch block {
                case .text:
                    transformedContent.append(block)

                case .thinking(let thinking):
                    if sameProvider {
                        // Keep thinking blocks as-is for the same provider
                        if thinking.redacted {
                            // Redacted thinking: keep signature for continuity
                            transformedContent.append(block)
                        } else {
                            transformedContent.append(block)
                        }
                    } else {
                        // Cross-provider: convert thinking to text with tags
                        if thinking.redacted {
                            // Can't use redacted thinking cross-provider — skip
                            continue
                        }
                        let wrappedText = "<thinking>\(thinking.thinking)</thinking>"
                        transformedContent.append(.text(TextContent(text: wrappedText)))
                    }

                case .toolCall(var toolCall):
                    // Normalize tool call IDs for cross-provider compatibility
                    let normalizedId = normalizeToolCallId(toolCall.id)
                    toolCall.id = normalizedId

                    if !sameProvider {
                        toolCall.thoughtSignature = nil
                    }

                    pendingToolCalls[normalizedId] = toolCall
                    transformedContent.append(.toolCall(toolCall))
                }
            }

            var transformed = assistantMsg
            transformed.content = transformedContent
            result.append(.assistant(transformed))

        case .toolResult(var toolResult):
            // Normalize the tool call ID to match
            toolResult.toolCallId = normalizeToolCallId(toolResult.toolCallId)
            pendingToolCalls.removeValue(forKey: toolResult.toolCallId)
            result.append(.toolResult(toolResult))
        }
    }

    // Handle orphaned tool calls — insert synthetic error results
    if !pendingToolCalls.isEmpty {
        for (id, toolCall) in pendingToolCalls {
            result.append(.toolResult(ToolResultMessage(
                toolCallId: id,
                toolName: toolCall.name,
                text: "No result provided",
                isError: true
            )))
        }
    }

    return result
}

/// Normalize a tool call ID to be compatible across providers.
///
/// OpenAI Responses generates pipe-separated IDs (e.g., `call_xxx|item_yyy`)
/// that can exceed 64 characters, which Anthropic rejects. This normalizes
/// to a safe alphanumeric format.
private func normalizeToolCallId(_ id: String) -> String {
    // If already clean and short enough, use as-is
    let cleaned = id.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    if cleaned == id && id.count <= 64 {
        return id
    }

    // Take the first segment (before pipe) and truncate
    let firstSegment = id.split(separator: "|").first.map(String.init) ?? id
    let truncated = String(firstSegment.prefix(64))
    return truncated.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
}
