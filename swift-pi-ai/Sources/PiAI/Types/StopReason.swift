// Why the model stopped generating.

public enum StopReason: String, Sendable, Codable, Equatable {
    case stop
    case length
    case toolUse
    case error
    case aborted
}
