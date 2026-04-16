import Testing
@testable import PiAI
import Foundation

@Suite("EventStream")
struct EventStreamTests {
    @Test func basicStreamAndResult() async {
        let stream = AssistantMessageEventStream()
        let msg = AssistantMessage(
            content: [.text(TextContent(text: "Hello"))],
            api: "test", provider: "test", model: "test"
        )

        Task {
            stream.push(.start(partial: msg))
            stream.push(.textStart(contentIndex: 0, partial: msg))
            stream.push(.textDelta(contentIndex: 0, delta: "Hello", partial: msg))
            stream.push(.textEnd(contentIndex: 0, content: "Hello", partial: msg))
            stream.push(.done(reason: .stop, message: msg))
        }

        let result = await stream.result()
        #expect(result.text == "Hello")
        #expect(result.stopReason == .stop)
    }

    @Test func iterateEvents() async {
        let stream = AssistantMessageEventStream()
        let msg = AssistantMessage(
            content: [.text(TextContent(text: "Hi"))],
            api: "test", provider: "test", model: "test"
        )

        Task {
            stream.push(.start(partial: msg))
            stream.push(.done(reason: .stop, message: msg))
        }

        var eventCount = 0
        for await _ in stream {
            eventCount += 1
        }
        #expect(eventCount == 2) // start + done
    }

    @Test func errorTermination() async {
        let stream = AssistantMessageEventStream()
        var msg = AssistantMessage(
            content: [], api: "test", provider: "test", model: "test"
        )
        msg.stopReason = .error
        msg.errorMessage = "Something went wrong"

        Task {
            stream.push(.start(partial: msg))
            stream.push(.error(reason: .error, message: msg))
        }

        let result = await stream.result()
        #expect(result.stopReason == .error)
        #expect(result.errorMessage == "Something went wrong")
    }

    @Test func resultReturnsImmediatelyIfAlreadyDone() async {
        let stream = AssistantMessageEventStream()
        let msg = AssistantMessage(
            content: [.text(TextContent(text: "Done"))],
            api: "test", provider: "test", model: "test"
        )

        stream.push(.start(partial: msg))
        stream.push(.done(reason: .stop, message: msg))

        // Drain the stream first
        for await _ in stream {}

        // result() should return immediately
        let result = await stream.result()
        #expect(result.text == "Done")
    }
}
