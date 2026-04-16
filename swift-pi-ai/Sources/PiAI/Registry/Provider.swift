// Provider protocol — the contract every AI provider implements.

/// Protocol for AI model providers.
///
/// Each provider translates the unified `Context` into its native API format,
/// streams responses back as `AssistantMessageEvent`s, and handles
/// provider-specific options.
public protocol AIProvider: Sendable {
    /// The API kind this provider handles.
    var apiKind: APIKind { get }

    /// Stream a response from the model.
    ///
    /// The returned stream must:
    /// 1. Emit `.start` before any partial updates
    /// 2. Terminate with `.done` or `.error`
    /// 3. Encode failures in the stream, not throw
    func stream(
        model: Model,
        context: Context,
        options: StreamOptions
    ) -> AssistantMessageEventStream

    /// Stream with unified reasoning options.
    ///
    /// Default implementation maps `SimpleStreamOptions` to `StreamOptions`
    /// and delegates to `stream()`. Providers override for native reasoning support.
    func streamSimple(
        model: Model,
        context: Context,
        options: SimpleStreamOptions
    ) -> AssistantMessageEventStream
}

// Default implementation: streamSimple delegates to stream.
extension AIProvider {
    public func streamSimple(
        model: Model,
        context: Context,
        options: SimpleStreamOptions
    ) -> AssistantMessageEventStream {
        stream(model: model, context: context, options: options.base)
    }
}
