import Testing
@testable import PiAI
import Foundation

@Suite("Message Transformation")
struct MessageTransformTests {
    let anthropicModel = Model(
        id: "claude-sonnet", name: "Claude", api: .anthropicMessages,
        provider: "anthropic", baseURL: "https://api.anthropic.com"
    )
    let openaiModel = Model(
        id: "gpt-4o", name: "GPT-4o", api: .openAICompletions,
        provider: "openai", baseURL: "https://api.openai.com"
    )

    @Test func userMessagesPassThrough() {
        let messages: [Message] = [
            .user(UserMessage("Hello")),
        ]
        let result = transformMessages(messages, for: anthropicModel)
        #expect(result.count == 1)
    }

    @Test func thinkingConvertedCrossProvider() {
        let messages: [Message] = [
            .assistant(AssistantMessage(
                content: [
                    .thinking(ThinkingContent(thinking: "Let me think...")),
                    .text(TextContent(text: "Here's my answer")),
                ],
                api: "anthropic-messages",
                provider: "anthropic",
                model: "claude-sonnet"
            )),
        ]

        // Same provider — keep thinking blocks
        let sameResult = transformMessages(messages, for: anthropicModel)
        if case .assistant(let msg) = sameResult[0] {
            #expect(msg.content.count == 2)
            if case .thinking = msg.content[0] {
                // Good — kept as thinking
            } else {
                Issue.record("Expected thinking block for same provider")
            }
        }

        // Cross provider — convert to text
        let crossResult = transformMessages(messages, for: openaiModel)
        if case .assistant(let msg) = crossResult[0] {
            #expect(msg.content.count == 2)
            if case .text(let t) = msg.content[0] {
                #expect(t.text.contains("<thinking>"))
            } else {
                Issue.record("Expected text block for cross provider")
            }
        }
    }

    @Test func errorMessagesSkipped() {
        let messages: [Message] = [
            .user(UserMessage("Hello")),
            .assistant(AssistantMessage(
                content: [.text(TextContent(text: "Partial"))],
                api: "test", provider: "test", model: "test",
                stopReason: .error, errorMessage: "Network error"
            )),
        ]

        let result = transformMessages(messages, for: anthropicModel)
        #expect(result.count == 1) // Only the user message
    }

    @Test func orphanedToolCallsGetSyntheticResults() {
        let messages: [Message] = [
            .assistant(AssistantMessage(
                content: [
                    .toolCall(ToolCall(id: "tc1", name: "search", arguments: ["q": "test"])),
                ],
                api: "test", provider: "anthropic", model: "test",
                stopReason: .toolUse
            )),
            // No tool result for tc1!
        ]

        let result = transformMessages(messages, for: anthropicModel)
        #expect(result.count == 2) // assistant + synthetic tool result
        if case .toolResult(let tr) = result[1] {
            #expect(tr.isError)
            #expect(tr.toolCallId == "tc1")
        }
    }
}
