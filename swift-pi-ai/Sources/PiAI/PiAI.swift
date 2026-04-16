// PiAI — Main entry points for streaming and completing model responses.
//
// This is the top-level API surface. It mirrors pi-ai's stream/complete/
// streamSimple/completeSimple pattern, routing through the provider registry.
//
// Usage:
//
//     import PiAI
//
//     // Register providers (typically at app startup)
//     PiAI.register(AnthropicProvider())
//     PiAI.register(OpenAIProvider())
//     PiAI.register(AppleIntelligenceProvider())
//
//     // Stream a response
//     let model = Model(
//         id: "claude-sonnet-4-6-20250514",
//         name: "Claude Sonnet 4.6",
//         api: .anthropicMessages,
//         provider: "anthropic",
//         baseURL: "https://api.anthropic.com"
//     )
//
//     let context = Context(
//         systemPrompt: "You are a helpful assistant.",
//         messages: [.user(UserMessage("Hello!"))]
//     )
//
//     for await event in PiAI.stream(model: model, context: context) {
//         switch event {
//         case .textDelta(_, let delta, _):
//             print(delta, terminator: "")
//         case .done(_, let message):
//             print("\n---\nTokens: \(message.usage.totalTokens)")
//         default:
//             break
//         }
//     }
//

import Foundation

/// Main namespace for PiAI operations.
public enum PiAI {

    // MARK: - Provider Registration

    /// Register a provider. Convenience wrapper around `ProviderRegistry.shared`.
    public static func register(_ provider: any AIProvider) {
        ProviderRegistry.shared.register(provider)
    }

    /// Register all built-in providers.
    public static func registerDefaults() {
        register(AnthropicProvider())
        register(OpenAIProvider())
        register(AppleIntelligenceProvider())
    }

    // MARK: - Streaming

    /// Stream a response from a model using provider-specific options.
    public static func stream(
        model: Model,
        context: Context,
        options: StreamOptions = StreamOptions()
    ) -> AssistantMessageEventStream {
        guard let provider = ProviderRegistry.shared.provider(for: model.api) else {
            let stream = AssistantMessageEventStream()
            Task {
                var msg = AssistantMessage(
                    content: [], api: model.api.rawValue,
                    provider: model.provider, model: model.id
                )
                msg.stopReason = .error
                msg.errorMessage = "No provider registered for API: \(model.api.rawValue)"
                stream.push(.start(partial: msg))
                stream.push(.error(reason: .error, message: msg))
            }
            return stream
        }
        return provider.stream(model: model, context: context, options: options)
    }

    /// Stream with unified reasoning options.
    public static func streamSimple(
        model: Model,
        context: Context,
        options: SimpleStreamOptions = SimpleStreamOptions()
    ) -> AssistantMessageEventStream {
        guard let provider = ProviderRegistry.shared.provider(for: model.api) else {
            let stream = AssistantMessageEventStream()
            Task {
                var msg = AssistantMessage(
                    content: [], api: model.api.rawValue,
                    provider: model.provider, model: model.id
                )
                msg.stopReason = .error
                msg.errorMessage = "No provider registered for API: \(model.api.rawValue)"
                stream.push(.start(partial: msg))
                stream.push(.error(reason: .error, message: msg))
            }
            return stream
        }
        return provider.streamSimple(model: model, context: context, options: options)
    }

    // MARK: - Completion (non-streaming)

    /// Get a complete response (non-streaming). Awaits the full result.
    public static func complete(
        model: Model,
        context: Context,
        options: StreamOptions = StreamOptions()
    ) async -> AssistantMessage {
        await stream(model: model, context: context, options: options).result()
    }

    /// Complete with unified reasoning options.
    public static func completeSimple(
        model: Model,
        context: Context,
        options: SimpleStreamOptions = SimpleStreamOptions()
    ) async -> AssistantMessage {
        await streamSimple(model: model, context: context, options: options).result()
    }

    // MARK: - Structured Output

    /// Generate a structured output conforming to a `Generable & Decodable` type.
    ///
    /// Inspired by Apple's `session.respond(to:generating:)` pattern.
    /// The schema is embedded in the system prompt and the model's JSON
    /// output is decoded into the requested type.
    ///
    /// ```swift
    /// struct MovieReview: Generable, Codable {
    ///     static var schema: JSONSchema {
    ///         .object(properties: [
    ///             "title": .string(description: "Movie title"),
    ///             "rating": .integer(description: "1-5 stars"),
    ///             "summary": .string(description: "Brief review"),
    ///         ], required: ["title", "rating", "summary"])
    ///     }
    ///     let title: String
    ///     let rating: Int
    ///     let summary: String
    /// }
    ///
    /// let review: MovieReview = try await PiAI.generate(
    ///     model: model,
    ///     prompt: "Review the movie Inception",
    ///     generating: MovieReview.self
    /// )
    /// ```
    public static func generate<T: Generable & Decodable>(
        model: Model,
        prompt: String,
        generating type: T.Type,
        systemPrompt: String? = nil,
        options: StreamOptions = StreamOptions()
    ) async throws -> T {
        let request = GenerateRequest<T>(prompt: prompt, systemPrompt: systemPrompt)
        let context = request.buildContext()
        let message = await complete(model: model, context: context, options: options)
        return try decodeGenerated(T.self, from: message)
    }

    // MARK: - Tool-Assisted Conversation

    /// Run a conversation turn with automatic tool execution.
    ///
    /// If the model returns tool calls, they are executed via the `ToolRegistry`,
    /// and the results are fed back to the model in a follow-up turn.
    /// This loops until the model produces a final text response or
    /// hits the maximum number of rounds.
    public static func completeWithTools(
        model: Model,
        context: Context,
        toolRegistry: ToolRegistry,
        options: StreamOptions = StreamOptions(),
        maxRounds: Int = 10
    ) async -> (message: AssistantMessage, messages: [Message]) {
        var messages = context.messages
        var currentContext = context

        for _ in 0..<maxRounds {
            let response = await complete(
                model: model,
                context: currentContext,
                options: options
            )

            messages.append(.assistant(response))

            // If no tool calls, we're done
            guard response.stopReason == .toolUse else {
                return (message: response, messages: messages)
            }

            let toolCalls = response.toolCalls
            guard !toolCalls.isEmpty else {
                return (message: response, messages: messages)
            }

            // Execute all tool calls
            let results = await toolRegistry.executeAll(toolCalls)
            for result in results {
                messages.append(.toolResult(result))
            }

            // Continue the conversation
            currentContext = Context(
                systemPrompt: context.systemPrompt,
                messages: messages,
                tools: context.tools
            )
        }

        // If we hit max rounds, return the last response
        let lastAssistant = messages.reversed().compactMap { msg -> AssistantMessage? in
            if case .assistant(let a) = msg { return a }
            return nil
        }.first!

        return (message: lastAssistant, messages: messages)
    }

    // MARK: - Convenience

    /// Quick one-shot text completion.
    public static func ask(
        model: Model,
        _ prompt: String,
        systemPrompt: String? = nil,
        options: StreamOptions = StreamOptions()
    ) async -> String {
        let context = Context(
            systemPrompt: systemPrompt,
            messages: [.user(UserMessage(prompt))]
        )
        let message = await complete(model: model, context: context, options: options)
        return message.text
    }
}

// MARK: - Pre-configured Models

extension PiAI {
    /// Well-known model configurations for quick setup.
    public enum Models {
        public static func claude(
            _ variant: String = "claude-sonnet-4-6-20250514",
            name: String = "Claude Sonnet 4.6"
        ) -> Model {
            Model(
                id: variant,
                name: name,
                api: .anthropicMessages,
                provider: "anthropic",
                baseURL: "https://api.anthropic.com",
                reasoning: variant.contains("opus"),
                inputModalities: [.text, .image],
                cost: ModelCost(input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75),
                contextWindow: 200_000,
                maxTokens: 8_192
            )
        }

        public static func gpt(
            _ variant: String = "gpt-4o",
            name: String = "GPT-4o"
        ) -> Model {
            Model(
                id: variant,
                name: name,
                api: .openAICompletions,
                provider: "openai",
                baseURL: "https://api.openai.com/v1",
                reasoning: variant.contains("o1") || variant.contains("o3"),
                inputModalities: [.text, .image],
                cost: ModelCost(input: 2.5, output: 10),
                contextWindow: 128_000,
                maxTokens: 4_096
            )
        }

        public static var appleIntelligence: Model {
            AppleIntelligenceProvider.onDeviceModel
        }
    }
}
