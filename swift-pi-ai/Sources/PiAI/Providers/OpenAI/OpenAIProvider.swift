// OpenAI Chat Completions API provider.
//
// Handles the OpenAI completions format (and OpenAI-compatible providers
// like Groq, xAI, etc.) — translating between unified PiAI types and
// the SSE event stream.

import Foundation

/// Provider for the OpenAI Chat Completions API.
public struct OpenAIProvider: AIProvider, Sendable {
    public let apiKind = APIKind.openAICompletions

    public init() {}

    public func stream(
        model: Model,
        context: Context,
        options: StreamOptions
    ) -> AssistantMessageEventStream {
        let eventStream = AssistantMessageEventStream()

        Task {
            var output = AssistantMessage(
                content: [],
                api: model.api.rawValue,
                provider: model.provider,
                model: model.id
            )

            do {
                let apiKey = options.apiKey ?? envAPIKey(provider: "openai") ?? ""
                let payload = try buildPayload(model: model, context: context, options: options)
                let request = try buildRequest(
                    baseURL: model.baseURL,
                    apiKey: apiKey,
                    payload: payload,
                    extraHeaders: options.headers
                )

                eventStream.push(.start(partial: output))

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ProviderError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = try? await collectErrorBody(bytes)
                    throw ProviderError.httpError(
                        statusCode: httpResponse.statusCode,
                        body: body ?? "HTTP \(httpResponse.statusCode)"
                    )
                }

                // Track active tool calls by index
                var toolCallBuilders: [Int: (id: String, name: String, args: String)] = [:]
                var currentTextIndex: Int?

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let data = String(line.dropFirst(6))
                    guard data != "[DONE]" else { break }
                    guard let eventData = data.data(using: .utf8) else { continue }

                    let chunk: OpenAIChunk
                    do {
                        chunk = try JSONDecoder().decode(OpenAIChunk.self, from: eventData)
                    } catch {
                        continue
                    }

                    output.responseId = output.responseId ?? chunk.id

                    // Usage from chunk
                    if let usage = chunk.usage {
                        output.usage.input = usage.prompt_tokens ?? 0
                        output.usage.output = usage.completion_tokens ?? 0
                        if let details = usage.prompt_tokens_details {
                            output.usage.cacheRead = details.cached_tokens ?? 0
                        }
                        output.usage.totalTokens = usage.total_tokens ?? 0
                    }

                    guard let choice = chunk.choices?.first else { continue }

                    // Finish reason
                    if let reason = choice.finish_reason {
                        output.stopReason = mapFinishReason(reason)
                    }

                    let delta = choice.delta

                    // Text content
                    if let content = delta?.content, !content.isEmpty {
                        if currentTextIndex == nil {
                            let idx = output.content.count
                            output.content.append(.text(TextContent(text: "")))
                            currentTextIndex = idx
                            eventStream.push(.textStart(contentIndex: idx, partial: output))
                        }

                        if let idx = currentTextIndex,
                           case .text(var tc) = output.content[idx]
                        {
                            tc.text += content
                            output.content[idx] = .text(tc)
                            eventStream.push(.textDelta(
                                contentIndex: idx, delta: content, partial: output
                            ))
                        }
                    }

                    // Tool calls
                    if let toolCalls = delta?.tool_calls {
                        // Close text block if we switch to tool calls
                        if let idx = currentTextIndex,
                           case .text(let tc) = output.content[idx]
                        {
                            eventStream.push(.textEnd(
                                contentIndex: idx, content: tc.text, partial: output
                            ))
                            currentTextIndex = nil
                        }

                        for tc in toolCalls {
                            let tcIndex = tc.index ?? 0
                            if let id = tc.id {
                                // New tool call starting
                                let contentIdx = output.content.count
                                let name = tc.function?.name ?? ""
                                toolCallBuilders[tcIndex] = (id: id, name: name, args: "")
                                output.content.append(.toolCall(ToolCall(id: id, name: name)))
                                eventStream.push(.toolCallStart(
                                    contentIndex: contentIdx, partial: output
                                ))
                            }

                            if let args = tc.function?.arguments {
                                if var builder = toolCallBuilders[tcIndex] {
                                    builder.args += args
                                    toolCallBuilders[tcIndex] = builder

                                    // Find content index for this tool call
                                    let contentIdx = output.content.count - toolCallBuilders.count + tcIndex
                                    eventStream.push(.toolCallDelta(
                                        contentIndex: contentIdx,
                                        delta: args,
                                        partial: output
                                    ))
                                }
                            }
                        }
                    }
                }

                // Finalize any open text block
                if let idx = currentTextIndex,
                   case .text(let tc) = output.content[idx]
                {
                    eventStream.push(.textEnd(
                        contentIndex: idx, content: tc.text, partial: output
                    ))
                }

                // Finalize tool calls
                for (tcIndex, builder) in toolCallBuilders.sorted(by: { $0.key < $1.key }) {
                    let parsed = parseJSON(builder.args) ?? [:]
                    let toolCall = ToolCall(id: builder.id, name: builder.name, arguments: parsed)

                    // Find content index
                    let contentIdx = output.content.count - toolCallBuilders.count + tcIndex
                    if contentIdx >= 0 && contentIdx < output.content.count {
                        output.content[contentIdx] = .toolCall(toolCall)
                        eventStream.push(.toolCallEnd(
                            contentIndex: contentIdx,
                            toolCall: toolCall,
                            partial: output
                        ))
                    }
                }

                output.usage.totalTokens = output.usage.input + output.usage.output
                    + output.usage.cacheRead + output.usage.cacheWrite
                output.usage.cost = model.cost.calculate(from: output.usage)

                let reason = output.stopReason
                switch reason {
                case .error, .aborted:
                    eventStream.push(.error(reason: reason, message: output))
                default:
                    eventStream.push(.done(reason: reason, message: output))
                }

            } catch {
                output.stopReason = .error
                output.errorMessage = error.localizedDescription
                eventStream.push(.error(reason: .error, message: output))
            }
        }

        return eventStream
    }
}

// MARK: - Request building

extension OpenAIProvider {
    private func buildRequest(
        baseURL: String,
        apiKey: String,
        payload: Data,
        extraHeaders: [String: String]?
    ) throws -> URLRequest {
        let urlString = baseURL.hasSuffix("/")
            ? "\(baseURL)chat/completions"
            : "\(baseURL)/chat/completions"

        guard let url = URL(string: urlString) else {
            throw ProviderError.invalidURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = payload

        if let extra = extraHeaders {
            for (key, value) in extra {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        return request
    }

    private func buildPayload(
        model: Model,
        context: Context,
        options: StreamOptions
    ) throws -> Data {
        var body: [String: JSONValue] = [
            "model": .string(model.id),
            "stream": true,
            "stream_options": .object(["include_usage": true]),
        ]

        if let temp = options.temperature {
            body["temperature"] = .double(temp)
        }
        if let maxTokens = options.maxTokens {
            body["max_tokens"] = .int(maxTokens)
        } else {
            body["max_tokens"] = .int(model.maxTokens)
        }

        // Build messages array
        var messages: [JSONValue] = []

        if let system = context.systemPrompt {
            messages.append(.object([
                "role": "system",
                "content": .string(system),
            ]))
        }

        for msg in context.messages {
            switch msg {
            case .user(let m):
                messages.append(.object([
                    "role": "user",
                    "content": .string(m.content.plainText),
                ]))
            case .assistant(let m):
                var msgObj: [String: JSONValue] = ["role": "assistant"]
                let textParts = m.content.compactMap { block -> String? in
                    if case .text(let t) = block { return t.text }
                    return nil
                }
                let toolCallParts = m.content.compactMap { block -> JSONValue? in
                    if case .toolCall(let tc) = block {
                        return .object([
                            "id": .string(tc.id),
                            "type": "function",
                            "function": .object([
                                "name": .string(tc.name),
                                "arguments": .string(encodeJSON(tc.arguments)),
                            ]),
                        ])
                    }
                    return nil
                }

                if !textParts.isEmpty {
                    msgObj["content"] = .string(textParts.joined())
                }
                if !toolCallParts.isEmpty {
                    msgObj["tool_calls"] = .array(toolCallParts)
                }
                if textParts.isEmpty && toolCallParts.isEmpty {
                    msgObj["content"] = .string("")
                }
                messages.append(.object(msgObj))

            case .toolResult(let m):
                let text = m.content.compactMap { block -> String? in
                    if case .text(let t) = block { return t.text }
                    return nil
                }.joined(separator: "\n")

                messages.append(.object([
                    "role": "tool",
                    "tool_call_id": .string(m.toolCallId),
                    "content": .string(text),
                ]))
            }
        }
        body["messages"] = .array(messages)

        // Tools
        if !context.tools.isEmpty {
            let toolDefs: [JSONValue] = context.tools.map { tool in
                .object([
                    "type": "function",
                    "function": .object([
                        "name": .string(tool.name),
                        "description": .string(tool.description),
                        "parameters": .object(tool.parameters.toJSON()),
                        "strict": true,
                    ]),
                ])
            }
            body["tools"] = .array(toolDefs)
        }

        return try JSONEncoder().encode(body)
    }

    private func mapFinishReason(_ reason: String) -> StopReason {
        switch reason {
        case "stop": return .stop
        case "length": return .length
        case "tool_calls": return .toolUse
        default: return .stop
        }
    }
}

// MARK: - OpenAI chunk types

private struct OpenAIChunk: Decodable {
    let id: String?
    let choices: [OpenAIChoice]?
    let usage: OpenAIUsage?
}

private struct OpenAIChoice: Decodable {
    let delta: OpenAIDelta?
    let finish_reason: String?
}

private struct OpenAIDelta: Decodable {
    let role: String?
    let content: String?
    let tool_calls: [OpenAIToolCallDelta]?
}

private struct OpenAIToolCallDelta: Decodable {
    let index: Int?
    let id: String?
    let function: OpenAIFunctionDelta?
}

private struct OpenAIFunctionDelta: Decodable {
    let name: String?
    let arguments: String?
}

private struct OpenAIUsage: Decodable {
    let prompt_tokens: Int?
    let completion_tokens: Int?
    let total_tokens: Int?
    let prompt_tokens_details: OpenAIPromptTokenDetails?
}

private struct OpenAIPromptTokenDetails: Decodable {
    let cached_tokens: Int?
}
