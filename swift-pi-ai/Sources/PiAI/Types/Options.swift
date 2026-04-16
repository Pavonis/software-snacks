// Options for streaming and completion requests.

import Foundation

/// Reasoning/thinking effort level — maps to provider-specific controls.
public enum ThinkingLevel: String, Sendable, Codable {
    case minimal, low, medium, high, xhigh
}

/// Cache retention preference for prompt caching.
public enum CacheRetention: String, Sendable, Codable {
    case none, short, long
}

/// Base options shared by all providers.
public struct StreamOptions: Sendable {
    public var temperature: Double?
    public var maxTokens: Int?
    public var apiKey: String?
    public var cacheRetention: CacheRetention?
    public var sessionId: String?
    public var headers: [String: String]?
    public var maxRetryDelayMs: Int?
    public var metadata: [String: JSONValue]?

    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        apiKey: String? = nil,
        cacheRetention: CacheRetention? = nil,
        sessionId: String? = nil,
        headers: [String: String]? = nil,
        maxRetryDelayMs: Int? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.apiKey = apiKey
        self.cacheRetention = cacheRetention
        self.sessionId = sessionId
        self.headers = headers
        self.maxRetryDelayMs = maxRetryDelayMs
        self.metadata = metadata
    }
}

/// Simplified options that use a unified reasoning level.
public struct SimpleStreamOptions: Sendable {
    public var base: StreamOptions
    public var reasoning: ThinkingLevel?
    public var thinkingBudgets: [ThinkingLevel: Int]?

    public init(
        base: StreamOptions = StreamOptions(),
        reasoning: ThinkingLevel? = nil,
        thinkingBudgets: [ThinkingLevel: Int]? = nil
    ) {
        self.base = base
        self.reasoning = reasoning
        self.thinkingBudgets = thinkingBudgets
    }
}
