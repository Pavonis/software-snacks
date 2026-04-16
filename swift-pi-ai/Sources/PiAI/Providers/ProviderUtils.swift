// Shared utilities for provider implementations.

import Foundation

/// Errors that providers can throw.
public enum ProviderError: Error, Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case noProviderRegistered(APIKind)
}

/// Look up an API key from environment variables.
///
/// Checks provider-specific env vars like ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.
public func envAPIKey(provider: String) -> String? {
    let envVarName: String
    switch provider.lowercased() {
    case "anthropic":
        envVarName = "ANTHROPIC_API_KEY"
    case "openai":
        envVarName = "OPENAI_API_KEY"
    case "google":
        envVarName = "GOOGLE_API_KEY"
    case "xai":
        envVarName = "XAI_API_KEY"
    case "groq":
        envVarName = "GROQ_API_KEY"
    case "mistral":
        envVarName = "MISTRAL_API_KEY"
    default:
        envVarName = "\(provider.uppercased())_API_KEY"
    }

    return ProcessInfo.processInfo.environment[envVarName]
}

/// Parse a JSON string into a dictionary of JSONValues.
/// Gracefully handles partial/malformed JSON (best-effort).
func parseJSON(_ jsonString: String) -> [String: JSONValue]? {
    guard !jsonString.isEmpty else { return [:] }

    // Try strict parsing first
    if let data = jsonString.data(using: .utf8),
       let result = try? JSONDecoder().decode([String: JSONValue].self, from: data)
    {
        return result
    }

    // Best-effort: try to fix common partial JSON issues
    var fixed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

    // Close unclosed braces
    let openBraces = fixed.filter { $0 == "{" }.count
    let closeBraces = fixed.filter { $0 == "}" }.count
    if openBraces > closeBraces {
        // Remove any trailing partial key-value pair
        if let lastComma = fixed.lastIndex(of: ",") {
            let afterComma = fixed[fixed.index(after: lastComma)...]
            // If what's after the comma doesn't look complete, truncate
            if !afterComma.contains(":") || !afterComma.contains("\"") {
                fixed = String(fixed[..<lastComma])
            }
        }
        fixed += String(repeating: "}", count: openBraces - closeBraces)
    }

    if let data = fixed.data(using: .utf8),
       let result = try? JSONDecoder().decode([String: JSONValue].self, from: data)
    {
        return result
    }

    return nil
}

/// Encode a dictionary of JSONValues to a JSON string.
func encodeJSON(_ dict: [String: JSONValue]) -> String {
    guard let data = try? JSONEncoder().encode(dict),
          let str = String(data: data, encoding: .utf8)
    else {
        return "{}"
    }
    return str
}

/// Collect error body from an async byte stream (for error reporting).
func collectErrorBody(_ bytes: URLSession.AsyncBytes) async throws -> String {
    var data = Data()
    for try await byte in bytes {
        data.append(byte)
        if data.count > 4096 { break } // Cap error body size
    }
    return String(data: data, encoding: .utf8) ?? "Unable to read error body"
}
