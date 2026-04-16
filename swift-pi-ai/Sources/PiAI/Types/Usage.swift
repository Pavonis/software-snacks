// Token usage and cost tracking.

/// Token usage from a model response.
public struct Usage: Sendable, Codable, Equatable {
    public var input: Int
    public var output: Int
    public var cacheRead: Int
    public var cacheWrite: Int
    public var totalTokens: Int
    public var cost: Cost

    public static let zero = Usage(
        input: 0, output: 0, cacheRead: 0, cacheWrite: 0,
        totalTokens: 0, cost: .zero
    )

    public init(
        input: Int, output: Int,
        cacheRead: Int = 0, cacheWrite: Int = 0,
        totalTokens: Int = 0, cost: Cost = .zero
    ) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.totalTokens = totalTokens
        self.cost = cost
    }

    /// Per-category cost breakdown.
    public struct Cost: Sendable, Codable, Equatable {
        public var input: Double
        public var output: Double
        public var cacheRead: Double
        public var cacheWrite: Double
        public var total: Double

        public static let zero = Cost(input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0)

        public init(input: Double, output: Double, cacheRead: Double, cacheWrite: Double, total: Double) {
            self.input = input
            self.output = output
            self.cacheRead = cacheRead
            self.cacheWrite = cacheWrite
            self.total = total
        }
    }
}

/// Cost per million tokens for a model.
public struct ModelCost: Sendable, Codable, Equatable {
    public var input: Double
    public var output: Double
    public var cacheRead: Double
    public var cacheWrite: Double

    public init(input: Double, output: Double, cacheRead: Double = 0, cacheWrite: Double = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }

    /// Calculate cost from token usage.
    public func calculate(from usage: Usage) -> Usage.Cost {
        let inputCost = (input / 1_000_000) * Double(usage.input)
        let outputCost = (output / 1_000_000) * Double(usage.output)
        let cacheReadCost = (cacheRead / 1_000_000) * Double(usage.cacheRead)
        let cacheWriteCost = (cacheWrite / 1_000_000) * Double(usage.cacheWrite)
        return Usage.Cost(
            input: inputCost,
            output: outputCost,
            cacheRead: cacheReadCost,
            cacheWrite: cacheWriteCost,
            total: inputCost + outputCost + cacheReadCost + cacheWriteCost
        )
    }
}
