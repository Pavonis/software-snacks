// Provider registry — central registration and lookup of AI providers.

import Foundation

/// Thread-safe registry for AI providers.
public final class ProviderRegistry: @unchecked Sendable {
    public static let shared = ProviderRegistry()

    private let lock = NSLock()
    private var providers: [APIKind: any AIProvider] = [:]
    private var customProviders: [String: any AIProvider] = [:]

    public init() {}

    /// Register a provider for a known API kind.
    public func register(_ provider: any AIProvider) {
        lock.lock()
        defer { lock.unlock() }
        providers[provider.apiKind] = provider
    }

    /// Register a provider with a custom string key (for extensibility).
    public func register(_ provider: any AIProvider, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        customProviders[key] = provider
    }

    /// Look up a provider by API kind.
    public func provider(for apiKind: APIKind) -> (any AIProvider)? {
        lock.lock()
        defer { lock.unlock() }
        return providers[apiKind]
    }

    /// Look up a provider by custom key.
    public func provider(forKey key: String) -> (any AIProvider)? {
        lock.lock()
        defer { lock.unlock() }
        return customProviders[key]
    }

    /// Remove all registered providers.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        providers.removeAll()
        customProviders.removeAll()
    }
}
