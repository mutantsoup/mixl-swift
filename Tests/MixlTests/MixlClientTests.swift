import Mixl
import MixlTesting
import XCTest

@testable import Mixl

final class MixlClientTests: XCTestCase {
    private var mockCloudService: MockMixlService!
    private var mockLocalService: MockMixlService!
    private var client: MixlClient!

    override func setUp() async throws {
        try await super.setUp()
        mockCloudService = MockMixlService()
        mockLocalService = MockMixlService()
        client = MixlClient(
            apiKey: "test-api-key",
            cloudService: mockCloudService,
            localService: mockLocalService
        )
    }

    // MARK: - Default Routing Tests

    func testDefaultRouterRoutesCloudModelToCloudService() async throws {
        // Given
        let expectedResponse = ChatCompletionResponse(
            id: "cloud-123",
            object: "chat.completion",
            created: 123456,
            model: "qwen/qwen3.5-4b-free",
            choices: [.init(index: 0, message: .init(role: .assistant, content: "Cloud response"), finishReason: "stop")],
            usage: .init(promptTokens: 5, completionTokens: 5, totalTokens: 10)
        )
        await mockCloudService.setStubbedResponse(expectedResponse)

        // When
        let response = try await client.chat.create(
            model: .qwen3_5_4b_free,
            messages: [.user("Hello")]
        )

        // Then
        XCTAssertEqual(response.id, "cloud-123")
        let cloudRequest = await mockCloudService.lastRequest
        XCTAssertNotNil(cloudRequest)
        XCTAssertEqual(cloudRequest?.model, Model.qwen3_5_4b_free.rawValue)

        let localRequest = await mockLocalService.lastRequest
        XCTAssertNil(localRequest)
    }

    func testDefaultRouterRoutesLocalModelToLocalService() async throws {
        // Given
        let expectedResponse = ChatCompletionResponse(
            id: "local-123",
            object: "chat.completion",
            created: 123456,
            model: "apple/foundation",
            choices: [.init(index: 0, message: .init(role: .assistant, content: "Local response"), finishReason: "stop")],
            usage: .init(promptTokens: 5, completionTokens: 5, totalTokens: 10)
        )
        await mockLocalService.setStubbedResponse(expectedResponse)

        // When
        let response = try await client.chat.create(
            model: .appleFoundation,
            messages: [.user("Hello")]
        )

        // Then
        XCTAssertEqual(response.id, "local-123")
        let localRequest = await mockLocalService.lastRequest
        XCTAssertNotNil(localRequest)
        XCTAssertEqual(localRequest?.model, Model.appleFoundation.rawValue)

        let cloudRequest = await mockCloudService.lastRequest
        XCTAssertNil(cloudRequest)
    }

    // MARK: - Custom Router Tests

    func testCustomRouterDecisionIsRespected() async throws {
        // Given
        struct EverythingToCloudRouter: MixlRouter {
            func route(
                request: ChatCompletionRequest,
                context: MixlRoutingContext
            ) async throws -> MixlRoutingDecision {
                // Route everything to cloud, but append "(routed)" to the model name
                let modifiedRequest = ChatCompletionRequest(
                    model: request.model + "-routed",
                    messages: request.messages,
                    thinking: request.thinking,
                    reasoningEffort: request.reasoningEffort,
                    temperature: request.temperature,
                    topP: request.topP,
                    topK: request.topK,
                    frequencyPenalty: request.frequencyPenalty,
                    presencePenalty: request.presencePenalty,
                    repetitionPenalty: request.repetitionPenalty,
                    maxCompletionTokens: request.maxCompletionTokens,
                    maxTokens: request.maxTokens,
                    stop: request.stop,
                    seed: request.seed,
                    stream: request.stream,
                    tools: request.tools,
                    responseFormat: request.responseFormat
                )
                return .cloud(modifiedRequest)
            }
        }

        let customClient = MixlClient(
            apiKey: "test-api-key",
            router: EverythingToCloudRouter(),
            cloudService: mockCloudService,
            localService: mockLocalService
        )

        let expectedResponse = ChatCompletionResponse(
            id: "cloud-custom",
            object: "chat.completion",
            created: 123456,
            model: "apple/foundation-routed",
            choices: [.init(index: 0, message: .init(role: .assistant, content: "Custom routed response"), finishReason: "stop")],
            usage: .init(promptTokens: 5, completionTokens: 5, totalTokens: 10)
        )
        await mockCloudService.setStubbedResponse(expectedResponse)

        // When
        let response = try await customClient.chat.create(
            model: .appleFoundation,
            messages: [.user("Hello")]
        )

        // Then
        XCTAssertEqual(response.id, "cloud-custom")
        let cloudRequest = await mockCloudService.lastRequest
        XCTAssertNotNil(cloudRequest)
        XCTAssertEqual(cloudRequest?.model, "apple/foundation-routed")

        let localRequest = await mockLocalService.lastRequest
        XCTAssertNil(localRequest)
    }

    // MARK: - Streaming Routing Tests

    func testStreamingRequestIsRoutedCorrectly() async throws {
        // Given
        let expectedChunk = ChatCompletionChunk(
            id: "stream-chunk-1",
            object: "chat.completion.chunk",
            created: 12345,
            model: "qwen/qwen3.5-4b-free",
            choices: [.init(index: 0, delta: .init(role: .assistant, content: "Stream segment"), finishReason: nil)]
        )
        await mockCloudService.setStubbedStreamChunks([expectedChunk])

        // When
        let stream = try await client.chat.createStream(
            model: .qwen3_5_4b_free,
            messages: [.user("Hello")]
        )

        var chunks: [ChatCompletionChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        // Then
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks.first?.id, "stream-chunk-1")
        XCTAssertEqual(chunks.first?.choices.first?.delta.content, "Stream segment")

        let cloudRequest = await mockCloudService.lastRequest
        XCTAssertNotNil(cloudRequest)
        XCTAssertEqual(cloudRequest?.model, Model.qwen3_5_4b_free.rawValue)

        let localRequest = await mockLocalService.lastRequest
        XCTAssertNil(localRequest)
    }

    // MARK: - Availability-Aware Default Router Tests

    func testDefaultRouterRoutesLocalWhenAvailable() async throws {
        // Given
        let router = MixlDefaultRouter()
        let request = ChatCompletionRequest(model: Model.appleFoundation.rawValue, messages: [.user("Hi")])
        let context = MixlRoutingContext(isLocalAvailable: true)

        // When
        let decision = try await router.route(request: request, context: context)

        // Then
        XCTAssertEqual(decision, .local(request))
    }

    func testDefaultRouterThrowsWhenLocalRequestedButUnavailable() async throws {
        // Given
        let router = MixlDefaultRouter()
        let request = ChatCompletionRequest(model: Model.appleFoundation.rawValue, messages: [.user("Hi")])
        let context = MixlRoutingContext(
            isLocalAvailable: false,
            localUnavailabilityReason: .deviceNotEligible
        )

        // When / Then
        do {
            _ = try await router.route(request: request, context: context)
            XCTFail("Expected route to throw when local is unavailable")
        } catch let error as MixlError {
            guard case .localModelUnavailable(let reason, _) = error else {
                return XCTFail("Expected localModelUnavailable, got \(error)")
            }
            XCTAssertEqual(reason, .deviceNotEligible)
        }
    }

    func testDefaultRouterRoutesCloudRegardlessOfLocalAvailability() async throws {
        // Given — cloud models are never gated by local availability
        let router = MixlDefaultRouter()
        let request = ChatCompletionRequest(model: Model.qwen3_5_4b_free.rawValue, messages: [.user("Hi")])
        let context = MixlRoutingContext(isLocalAvailable: false, localUnavailabilityReason: .frameworkNotAvailable)

        // When
        let decision = try await router.route(request: request, context: context)

        // Then
        XCTAssertEqual(decision, .cloud(request))
    }

    // MARK: - Routing Context Plumbing Tests

    /// Captures the ``MixlRoutingContext`` passed to a router so tests can assert how ``MixlClient`` computes it.
    private actor ContextRecorder {
        private(set) var context: MixlRoutingContext?
        func record(_ context: MixlRoutingContext) { self.context = context }
    }

    private struct RecordingRouter: MixlRouter {
        let recorder: ContextRecorder
        func route(
            request: ChatCompletionRequest,
            context: MixlRoutingContext
        ) async throws -> MixlRoutingDecision {
            await recorder.record(context)
            return .cloud(request)
        }
    }

    func testRoutingContextReportsLocalAvailableWhenLocalServiceInjected() async throws {
        // Given — an injected local service governs availability, so the context must report it available
        let recorder = ContextRecorder()
        let recordingClient = MixlClient(
            apiKey: "test-api-key",
            router: RecordingRouter(recorder: recorder),
            cloudService: mockCloudService,
            localService: mockLocalService
        )
        await mockCloudService.setStubbedResponse(
            ChatCompletionResponse(
                id: "ctx-1",
                object: "chat.completion",
                created: 1,
                model: "qwen/qwen3.5-4b-free",
                choices: [.init(index: 0, message: .init(role: .assistant, content: "ok"), finishReason: "stop")],
                usage: .init(promptTokens: 1, completionTokens: 1, totalTokens: 2)
            )
        )

        // When
        _ = try await recordingClient.chat.create(model: .qwen3_5_4b_free, messages: [.user("Hi")])

        // Then
        let context = await recorder.context
        XCTAssertEqual(context?.isLocalAvailable, true)
        XCTAssertNil(context?.localUnavailabilityReason)
    }
}
