import Mixl
import MixlTesting
import XCTest

@testable import Mixl

final class MixlRequestTransformTests: XCTestCase {
    private var mockCloudService: MockMixlService!
    private var mockLocalService: MockMixlService!

    override func setUp() async throws {
        try await super.setUp()
        mockCloudService = MockMixlService()
        mockLocalService = MockMixlService()
    }

    private func stubCloudResponse() async {
        await mockCloudService.setStubbedResponse(
            ChatCompletionResponse(
                id: "resp-1",
                object: "chat.completion",
                created: 1,
                model: "qwen/qwen3.5-4b-free",
                choices: [.init(index: 0, message: .init(role: .assistant, content: "ok"), finishReason: "stop")],
                usage: .init(promptTokens: 1, completionTokens: 1, totalTokens: 2)
            )
        )
    }

    private func makeClient(transforms: [any MixlRequestTransform]) -> MixlClient {
        MixlClient(
            apiKey: "test-api-key",
            transforms: transforms,
            cloudService: mockCloudService,
            localService: mockLocalService
        )
    }

    // MARK: - Basic transform application

    func testTransformRewritesRequestBeforeRouting() async throws {
        // Given — a transform that strips "um" filler from message content
        let stripFiller = MixlTransform.mapContent {
            $0.replacingOccurrences(of: "um, ", with: "")
        }
        let client = makeClient(transforms: [stripFiller])
        await stubCloudResponse()

        // When
        _ = try await client.chat.create(
            model: .qwen3_5_4b_free,
            messages: [.user("um, what is the capital of France?")]
        )

        // Then — the cloud service sees the cleaned prompt, not the original
        let received = await mockCloudService.lastRequest
        XCTAssertEqual(received?.messages.first?.content, "what is the capital of France?")
    }

    func testTransformChainAppliesInOrder() async throws {
        // Given — two transforms; the second depends on the first having run
        let appendOne = MixlTransform.mapContent { $0 + "-1" }
        let appendTwo = MixlTransform.mapContent { $0 + "-2" }
        let client = makeClient(transforms: [appendOne, appendTwo])
        await stubCloudResponse()

        // When
        _ = try await client.chat.create(model: .qwen3_5_4b_free, messages: [.user("base")])

        // Then — applied left-to-right
        let received = await mockCloudService.lastRequest
        XCTAssertEqual(received?.messages.first?.content, "base-1-2")
    }

    func testEmptyTransformChainLeavesRequestUnchanged() async throws {
        // Given
        let client = makeClient(transforms: [])
        await stubCloudResponse()

        // When
        _ = try await client.chat.create(model: .qwen3_5_4b_free, messages: [.user("untouched")])

        // Then
        let received = await mockCloudService.lastRequest
        XCTAssertEqual(received?.messages.first?.content, "untouched")
    }

    // MARK: - Routing context plumbing

    func testTransformReceivesRoutingContext() async throws {
        // Given — a transform that records the context it is handed
        let recorder = ContextBox()
        let recording = MixlTransform { request, context in
            await recorder.record(context)
            return request
        }
        let client = makeClient(transforms: [recording])
        await stubCloudResponse()

        // When
        _ = try await client.chat.create(model: .qwen3_5_4b_free, messages: [.user("Hi")])

        // Then — an injected local service reports local as available
        let context = await recorder.value
        XCTAssertEqual(context?.isLocalAvailable, true)
    }

    // MARK: - Throwing transform aborts the request

    func testThrowingTransformPreventsBackendCall() async throws {
        // Given — a transform that rejects the request
        struct BlockedError: Error, Equatable {}
        let blocker = MixlTransform { _, _ in throw BlockedError() }
        let client = makeClient(transforms: [blocker])
        await stubCloudResponse()

        // When / Then
        do {
            _ = try await client.chat.create(model: .qwen3_5_4b_free, messages: [.user("secret")])
            XCTFail("Expected the transform to abort the request")
        } catch is BlockedError {
            // Expected — and the backend must never have been reached
            let received = await mockCloudService.lastRequest
            XCTAssertNil(received)
        }
    }

    // MARK: - Streaming

    func testTransformAppliesToStreamingRequests() async throws {
        // Given
        let redact = MixlTransform.mapContent {
            $0.replacingOccurrences(of: "Project Cerberus", with: "[REDACTED]")
        }
        let client = makeClient(transforms: [redact])
        await mockCloudService.setStubbedStreamChunks([
            ChatCompletionChunk(
                id: "chunk-1",
                object: "chat.completion.chunk",
                created: 1,
                model: "qwen/qwen3.5-4b-free",
                choices: [.init(index: 0, delta: .init(role: .assistant, content: "ok"), finishReason: nil)]
            )
        ])

        // When
        let stream = try await client.chat.createStream(
            model: .qwen3_5_4b_free,
            messages: [.user("Summarize Project Cerberus")]
        )
        for try await _ in stream {}

        // Then
        let received = await mockCloudService.lastRequest
        XCTAssertEqual(received?.messages.first?.content, "Summarize [REDACTED]")
    }

    // MARK: - mapContent helper semantics

    func testMapContentSkipsNilContentAndPreservesFields() async throws {
        // Given — a request mixing a system message, a user message, and an assistant tool-call
        // message with nil content; mapContent must touch only the text and preserve everything else.
        let toolCall = ToolCall(id: "call-1", function: .init(name: "lookup", arguments: "{}"))
        let request = ChatCompletionRequest(
            model: Model.qwen3_5_4b_free.rawValue,
            messages: [
                .system("be concise"),
                Message(role: .assistant, content: nil, toolCalls: [toolCall]),
                .user("hello", name: "John")
            ],
            temperature: 0.7
        )

        // When
        let mapped = request.mappingContent { $0.uppercased() }

        // Then — content rewritten where present, nil preserved, other fields intact
        XCTAssertEqual(mapped.messages[0].content, "BE CONCISE")
        XCTAssertNil(mapped.messages[1].content)
        XCTAssertEqual(mapped.messages[1].toolCalls, [toolCall])
        XCTAssertEqual(mapped.messages[2].content, "HELLO")
        XCTAssertEqual(mapped.messages[2].name, "John")
        // Non-message parameters are untouched
        XCTAssertEqual(mapped.temperature, 0.7)
        XCTAssertEqual(mapped.model, Model.qwen3_5_4b_free.rawValue)
    }
}

/// A small async-safe box for capturing a value handed to a closure under test.
private actor ContextBox {
    private(set) var value: MixlRoutingContext?
    func record(_ context: MixlRoutingContext) { value = context }
}
