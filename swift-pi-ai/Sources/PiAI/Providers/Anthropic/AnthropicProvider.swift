// Anthropic Messages API provider.
//
// Streams responses from the Anthropic Messages API, translating between
// the unified PiAI types and Anthropic's SSE event format.

import Foundation

/// Provider for the Anthropic Messages API.
public struct AnthropicProvider: AIProvider, Sendable {
    public let apiKind = APIKind.anthropicMessages

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
                let apiKey = options.apiKey ?? envAPIKey(provider: "anthropic") ?? ""
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

                // Parse SSE events
                var currentBlockIndex = -1
                var partialToolArgs = ""

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let data = String(line.dropFirst(6))
                    guard data != "[DONE]" else { break }
                    guard let eventData = data.data(using: .utf8) else { continue }

                    let event = try JSONDecoder().decode(AnthropicSSEEvent.self, from: eventData)

                    switch event.type {
                    case "message_start":
                        if let usage = event.message?.usage {
                            output.usage.input = usage.input_tokens ?? 0
                            output.usage.output = usage.output_tokens ?? 0
                            output.usage.cacheRead = usage.cache_read_input_tokens ?? 0
                            output.usage.cacheWrite = usage.cache_creation_input_tokens ?? 0
                        }

                    case "content_block_start":
                        currentBlockIndex += 1
                        if let block = event.content_block {
                            switch block.type {
                            case "text":
                                output.content.append(.text(TextContent(text: "")))
                                eventStream.push(.textStart(
                                    contentIndex: currentBlockIndex, partial: output
                                ))
                            case "thinking":
                                output.content.append(.thinking(ThinkingContent(thinking: "")))
                                eventStream.push(.thinkingStart(
                                    contentIndex: currentBlockIndex, partial: output
                                ))
                            case "tool_use":
                                partialToolArgs = ""
                                let tc = ToolCall(
                                    id: block.id ?? "",
                                    name: block.name ?? ""
                                )
                                output.content.append(.toolCall(tc))
                                eventStream.push(.toolCallStart(
                                    contentIndex: currentBlockIndex, partial: output
                                ))
                            default:
                                break
                            }
                        }

                    case "content_block_delta":
                        if let delta = event.delta {
                            switch delta.type {
                            case "text_delta":
                                let text = delta.text ?? ""
                                if currentBlockIndex < output.content.count,
                                   case .text(var tc) = output.content[currentBlockIndex]
                                {
                                    tc.text += text
                                    output.content[currentBlockIndex] = .text(tc)
                                }
                                eventStream.push(.textDelta(
                                    contentIndex: currentBlockIndex,
                                    delta: text,
                                    partial: output
                                ))

                            case "thinking_delta":
                                let text = delta.thinking ?? ""
                                if currentBlockIndex < output.content.count,
                                   case .thinking(var tc) = output.content[currentBlockIndex]
                                {
                                    tc.thinking += text
                                    output.content[currentBlockIndex] = .thinking(tc)
                                }
                                eventStream.push(.thinkingDelta(
                                    contentIndex: currentBlockIndex,
                                    delta: text,
                                    partial: output
                                ))

                            case "input_json_delta":
                                let fragment = delta.partial_json ?? ""
                                partialToolArgs += fragment
                                eventStream.push(.toolCallDelta(
                                    contentIndex: currentBlockIndex,
                                    delta: fragment,
                                    partial: output
                                ))

                            default:
                                break
                            }
                        }

                    case "content_block_stop":
                        if currentBlockIndex < output.content.count {
                            switch output.content[currentBlockIndex] {
                            case .text(let tc):
                                eventStream.push(.textEnd(
                                    contentIndex: currentBlockIndex,
                                    content: tc.text,
                                    partial: output
                                ))
                            case .thinking(let tc):
                                if let sig = event.delta?.thinking_signature {
                                    var updated = tc
                                    updated.thinkingSignature = sig
                                    output.content[currentBlockIndex] = .thinking(updated)
                                }
                                eventStream.push(.thinkingEnd(
                                    contentIndex: currentBlockIndex,
                                    content: tc.thinking,
                                    partial: output
                                ))
                            case .toolCall(var tc):
                                if let parsed = parseJSON(partialToolArgs) {
                                    tc.arguments = parsed
                                }
                                output.content[currentBlockIndex] = .toolCall(tc)
                                partialToolArgs = ""
                                eventStream.push(.toolCallEnd(
                                    contentIndex: currentBlockIndex,
                                    toolCall: tc,
                                    partial: output
                                ))
                            }
                        }

                    case "message_delta":
                        if let delta = event.delta {
                            if let sr = delta.stop_reason {
                                output.stopReason = mapStopReason(sr)
                            }
                            if let usage = delta.usage {
                                output.usage.output = usage.output_tokens ?? output.usage.output
                            }
                        }

                    case "message_stop":
                        break

                    default:
                        break
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

    public func streamSimple(
        model: Model,
        context: Context,
        options: SimpleStreamOptions
    ) -> AssistantMessageEventStream {
        // Map reasoning level to Anthropic thinking options via base options
        var baseOpts = options.base
        // For now, delegate to stream() — a full implementation would set
        // thinking budget headers based on the reasoning level.
        if options.reasoning != nil {
            baseOpts.metadata = baseOpts.metadata ?? [:]
            if let reasoning = options.reasoning {
                baseOpts.metadata?["_thinkingLevel"] = .string(reasoning.rawValue)
            }
        }
        return stream(model: model, context: context, options: baseOpts)
    }
}

// MARK: - Request building

extension AnthropicProvider {
    private func buildRequest(
        baseURL: String,
        apiKey: String,
        payload: Data,
        extraHeaders: [String: String]?
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw ProviderError.invalidURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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
            "max_tokens": .int(options.maxTokens ?? model.maxTokens),
        ]

        if let temp = options.temperature {
            body["temperature"] = .double(temp)
        }

        if let system = context.systemPrompt {
            body["system"] = .string(system)
        }

        // Convert messages
        var messages: [JSONValue] = []
        for msg in context.messages {
            switch msg {
            case .user(let m):
                messages.append(.object([
                    "role": "user",
                    "content": .string(m.content.plainText),
                ]))
            case .assistant(let m):
                var content: [JSONValue] = []
                for block in m.content {
                    switch block {
                    case .text(let t):
                        content.append(.object(["type": "text", "text": .string(t.text)]))
                    case .thinking(let t):
                        var thinkObj: [String: JSONValue] = [
                            "type": "thinking",
                            "thinking": .string(t.thinking),
                        ]
                        if let sig = t.thinkingSignature {
                            thinkObj["signature"] = .string(sig)
                        }
                        content.append(.object(thinkObj))
                    case .toolCall(let tc):
                        content.append(.object([
                            "type": "tool_use",
                            "id": .string(tc.id),
                            "name": .string(tc.name),
                            "input": .object(tc.arguments),
                        ]))
                    }
                }
                messages.append(.object([
                    "role": "assistant",
                    "content": .array(content),
                ]))
            case .toolResult(let m):
                var resultContent: [JSONValue] = []
                for block in m.content {
                    switch block {
                    case .text(let t):
                        resultContent.append(.object(["type": "text", "text": .string(t.text)]))
                    case .image(let img):
                        resultContent.append(.object([
                            "type": "image",
                            "source": .object([
                                "type": "base64",
                                "media_type": .string(img.mimeType),
                                "data": .string(img.data),
                            ]),
                        ]))
                    }
                }
                messages.append(.object([
                    "role": "user",
                    "content": .array([
                        .object([
                            "type": "tool_result",
                            "tool_use_id": .string(m.toolCallId),
                            "content": .array(resultContent),
                            "is_error": .bool(m.isError),
                        ])
                    ]),
                ]))
            }
        }
        body["messages"] = .array(messages)

        // Convert tools
        if !context.tools.isEmpty {
            let toolDefs: [JSONValue] = context.tools.map { tool in
                .object([
                    "name": .string(tool.name),
                    "description": .string(tool.description),
                    "input_schema": .object(tool.parameters.toJSON()),
                ])
            }
            body["tools"] = .array(toolDefs)
        }

        // Check for thinking level in metadata
        if let thinkingLevel = options.metadata?["_thinkingLevel"]?.stringValue {
            body["thinking"] = .object([
                "type": "enabled",
                "budget_tokens": .int(thinkingBudget(for: thinkingLevel)),
            ])
            // Increase max_tokens to accommodate thinking
            let currentMax = options.maxTokens ?? model.maxTokens
            let budget = thinkingBudget(for: thinkingLevel)
            body["max_tokens"] = .int(max(currentMax, budget + 1024))
        }

        return try JSONEncoder().encode(body)
    }

    private func thinkingBudget(for level: String) -> Int {
        switch level {
        case "minimal": return 1024
        case "low": return 2048
        case "medium": return 8192
        case "high": return 16384
        case "xhigh": return 32768
        default: return 8192
        }
    }

    private func mapStopReason(_ reason: String) -> StopReason {
        switch reason {
        case "end_turn", "stop": return .stop
        case "max_tokens": return .length
        case "tool_use": return .toolUse
        default: return .stop
        }
    }
}

// MARK: - SSE event types (internal)

private struct AnthropicSSEEvent: Decodable {
    let type: String
    let message: AnthropicMessage?
    let content_block: AnthropicContentBlock?
    let delta: AnthropicDelta?
    let index: Int?
}

private struct AnthropicMessage: Decodable {
    let id: String?
    let usage: AnthropicUsage?
}

private struct AnthropicContentBlock: Decodable {
    let type: String
    let id: String?
    let name: String?
    let text: String?
}

private struct AnthropicDelta: Decodable {
    let type: String?
    let text: String?
    let thinking: String?
    let partial_json: String?
    let stop_reason: String?
    let thinking_signature: String?
    let usage: AnthropicUsage?
}

private struct AnthropicUsage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
    let cache_read_input_tokens: Int?
    let cache_creation_input_tokens: Int?
}
