// JSON Schema representation for tool parameters.
// Provides a Swift-native way to build JSON Schema definitions.

/// A JSON Schema definition for describing tool parameters.
///
/// Designed to be expressive enough for tool calling while staying simple.
/// Serializes to the JSON Schema subset that LLM providers expect.
public indirect enum JSONSchema: Sendable, Equatable {
    case string(description: String? = nil)
    case integer(description: String? = nil)
    case number(description: String? = nil)
    case boolean(description: String? = nil)
    case `enum`(values: [String], description: String? = nil)
    case array(items: JSONSchema, description: String? = nil)
    case object(properties: [String: JSONSchema], required: [String] = [], description: String? = nil)
    case anyOf([JSONSchema], description: String? = nil)

    /// Convert to a JSON-compatible dictionary for API payloads.
    public func toJSON() -> [String: JSONValue] {
        switch self {
        case .string(let desc):
            var result: [String: JSONValue] = ["type": "string"]
            if let desc { result["description"] = .string(desc) }
            return result

        case .integer(let desc):
            var result: [String: JSONValue] = ["type": "integer"]
            if let desc { result["description"] = .string(desc) }
            return result

        case .number(let desc):
            var result: [String: JSONValue] = ["type": "number"]
            if let desc { result["description"] = .string(desc) }
            return result

        case .boolean(let desc):
            var result: [String: JSONValue] = ["type": "boolean"]
            if let desc { result["description"] = .string(desc) }
            return result

        case .enum(let values, let desc):
            var result: [String: JSONValue] = [
                "type": "string",
                "enum": .array(values.map { .string($0) }),
            ]
            if let desc { result["description"] = .string(desc) }
            return result

        case .array(let items, let desc):
            var result: [String: JSONValue] = [
                "type": "array",
                "items": .object(items.toJSON()),
            ]
            if let desc { result["description"] = .string(desc) }
            return result

        case .object(let properties, let required, let desc):
            var props: [String: JSONValue] = [:]
            for (key, schema) in properties {
                props[key] = .object(schema.toJSON())
            }
            var result: [String: JSONValue] = [
                "type": "object",
                "properties": .object(props),
            ]
            if !required.isEmpty {
                result["required"] = .array(required.map { .string($0) })
            }
            if let desc { result["description"] = .string(desc) }
            return result

        case .anyOf(let schemas, let desc):
            var result: [String: JSONValue] = [
                "anyOf": .array(schemas.map { .object($0.toJSON()) })
            ]
            if let desc { result["description"] = .string(desc) }
            return result
        }
    }
}
