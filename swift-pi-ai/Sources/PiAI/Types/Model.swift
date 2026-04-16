// Model definition — describes a specific model from a provider.

/// A specific model available from a provider.
public struct Model: Sendable, Equatable {
    public var id: String
    public var name: String
    public var api: APIKind
    public var provider: String
    public var baseURL: String
    public var reasoning: Bool
    public var inputModalities: Set<InputModality>
    public var cost: ModelCost
    public var contextWindow: Int
    public var maxTokens: Int
    public var headers: [String: String]

    public init(
        id: String,
        name: String,
        api: APIKind,
        provider: String,
        baseURL: String,
        reasoning: Bool = false,
        inputModalities: Set<InputModality> = [.text],
        cost: ModelCost = ModelCost(input: 0, output: 0),
        contextWindow: Int = 128_000,
        maxTokens: Int = 4_096,
        headers: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.api = api
        self.provider = provider
        self.baseURL = baseURL
        self.reasoning = reasoning
        self.inputModalities = inputModalities
        self.cost = cost
        self.contextWindow = contextWindow
        self.maxTokens = maxTokens
        self.headers = headers
    }
}

/// The API protocol a model uses.
public enum APIKind: String, Sendable, Codable, Equatable, Hashable {
    case anthropicMessages = "anthropic-messages"
    case openAICompletions = "openai-completions"
    case openAIResponses = "openai-responses"
    case googleGenerativeAI = "google-generative-ai"
    case appleIntelligence = "apple-intelligence"

    /// Extensibility: an API kind not covered by the built-in cases.
    case custom
}

/// What input modalities a model supports.
public enum InputModality: String, Sendable, Codable, Equatable, Hashable {
    case text
    case image
}
