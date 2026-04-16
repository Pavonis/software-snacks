// Async event stream with backpressure support.
// Swift equivalent of pi-ai's EventStream, built on AsyncStream.

import Foundation

/// An async stream of assistant message events, plus a `result()` method
/// that returns the final message once streaming completes.
///
/// This is the primary return type from provider `stream()` methods.
/// Consumers can either iterate the events for live updates or just
/// await `result()` for the final message.
public final class AssistantMessageEventStream: AsyncSequence, @unchecked Sendable {
    public typealias Element = AssistantMessageEvent

    private let stream: AsyncStream<AssistantMessageEvent>
    private let continuation: AsyncStream<AssistantMessageEvent>.Continuation
    private let resultContinuation: CheckedContinuation<AssistantMessage, Never>?

    // Thread-safe storage for the final result
    private let lock = NSLock()
    private var finalResult: AssistantMessage?
    private var resultWaiters: [CheckedContinuation<AssistantMessage, Never>] = []
    private var isDone = false

    public init() {
        var cont: AsyncStream<AssistantMessageEvent>.Continuation!
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
        self.resultContinuation = nil
    }

    /// Push an event into the stream.
    public func push(_ event: AssistantMessageEvent) {
        lock.lock()
        guard !isDone else {
            lock.unlock()
            return
        }

        if event.isTerminal {
            isDone = true
            let message: AssistantMessage
            switch event {
            case .done(_, let m): message = m
            case .error(_, let m): message = m
            default: fatalError("unreachable")
            }
            finalResult = message
            let waiters = resultWaiters
            resultWaiters = []
            lock.unlock()

            continuation.yield(event)
            continuation.finish()
            for waiter in waiters {
                waiter.resume(returning: message)
            }
        } else {
            lock.unlock()
            continuation.yield(event)
        }
    }

    /// End the stream without a terminal event (for error paths that
    /// can't construct a proper event).
    public func end(with message: AssistantMessage? = nil) {
        lock.lock()
        guard !isDone else {
            lock.unlock()
            return
        }
        isDone = true
        if let message {
            finalResult = message
        }
        let waiters = resultWaiters
        let result = finalResult
        resultWaiters = []
        lock.unlock()

        continuation.finish()
        if let result {
            for waiter in waiters {
                waiter.resume(returning: result)
            }
        }
    }

    /// Await the final assistant message.
    ///
    /// If the stream has already completed, returns immediately.
    /// Otherwise suspends until a terminal event is pushed.
    public func result() async -> AssistantMessage {
        lock.lock()
        if let result = finalResult {
            lock.unlock()
            return result
        }
        lock.unlock()

        return await withCheckedContinuation { continuation in
            lock.lock()
            if let result = finalResult {
                lock.unlock()
                continuation.resume(returning: result)
            } else {
                resultWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    // MARK: - AsyncSequence conformance

    public struct AsyncIterator: AsyncIteratorProtocol {
        var base: AsyncStream<AssistantMessageEvent>.AsyncIterator

        public mutating func next() async -> AssistantMessageEvent? {
            await base.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: stream.makeAsyncIterator())
    }
}
