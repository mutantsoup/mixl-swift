import Foundation

/// A unified orchestrator client that routes requests to either the MixLayer cloud or on-device local models.
///
/// Use ``MixlClient`` as your primary client instance to leverage hybrid inference. By default, it uses
/// ``MixlDefaultRouter`` to automatically route `.appleFoundation` models to the local on-device client, and
/// all other models to the MixLayer cloud client.
///
/// ## Overview
///
/// Under the hood, ``MixlClient`` acts as a dispatcher. It delegates requests to the injected ``MixlRouter``,
/// which selects between the cloud or local service based on availability and constraints.
///
/// ## Example
///
/// ```swift
/// let client = MixlClient(apiKey: "your-api-key")
///
/// // Automatically routes to the cloud backend
/// let cloudResponse = try await client.chat.create(
///     model: .qwen3_5_4b_free,
///     messages: [.user("Hello!")]
/// )
///
/// // Automatically routes to the on-device backend (if available)
/// if #available(iOS 26.0, macOS 26.0, *) {
///     let localResponse = try await client.chat.create(
///         model: .appleFoundation,
///         messages: [.user("What is 2+2?")]
///     )
/// }
/// ```
public final class MixlClient: MixlService, Sendable {
    /// The API key used to authenticate MixLayer cloud requests.
    public let apiKey: String

    /// The base server URL for the MixLayer API cloud endpoints.
    public let baseURL: URL

    internal let cloudService: any MixlService
    internal let localService: any MixlService
    internal let router: any MixlRouter

    /// Whether ``localService`` was supplied by the caller.
    ///
    /// When `true`, the injected service governs local availability and the orchestrator reports
    /// local inference as available in the routing context. When `false`, availability is determined
    /// at runtime by ``LocalModelSupport/unavailabilityReason()``.
    internal let localServiceInjected: Bool

    /// Entry point for chat completions endpoints.
    ///
    /// Exposes standard non-streaming (`create`) and streaming (`createStream`) chat completion methods.
    public var chat: MixlChatCompletionsService {
        MixlChatCompletionsService(service: self)
    }

    /// Initializes a new orchestrator client.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for MixLayer cloud authentication.
    ///   - baseURL: The base URL of the API. Defaults to `https://models.mixlayer.ai/v1`.
    ///   - session: The `URLSession` used for network requests.
    ///   - router: The routing policy to use. Defaults to ``MixlDefaultRouter``.
    ///   - cloudService: An optional ``MixlService`` implementation to inject for cloud testing.
    ///   - localService: An optional ``MixlService`` implementation to inject for local testing.
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://models.mixlayer.ai/v1")!,
        session: URLSession = .shared,
        router: any MixlRouter = MixlDefaultRouter(),
        cloudService: (any MixlService)? = nil,
        localService: (any MixlService)? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.router = router
        self.cloudService = cloudService ?? MixLayerAPIService(apiKey: apiKey, baseURL: baseURL, session: session)
        self.localServiceInjected = localService != nil

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            self.localService = localService ?? LocalInferenceService()
        } else {
            self.localService = localService ?? LocalUnavailableInferenceService(reason: .frameworkNotAvailable)
        }
        #else
        self.localService = localService ?? LocalUnavailableInferenceService(reason: .frameworkNotAvailable)
        #endif
    }

    /// Submits a standard chat completion request, routing it according to the configured router.
    public func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        let context = makeRoutingContext()
        let decision = try await router.route(request: request, context: context)
        switch decision {
        case .cloud(let routedRequest):
            return try await cloudService.createChatCompletion(request: routedRequest)
        case .local(let routedRequest):
            return try await localService.createChatCompletion(request: routedRequest)
        }
    }

    /// Submits a streaming chat completion request, routing it according to the configured router.
    public func createChatCompletionStream(request: ChatCompletionRequest) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let context = makeRoutingContext()
        let decision = try await router.route(request: request, context: context)
        switch decision {
        case .cloud(let routedRequest):
            return try await cloudService.createChatCompletionStream(request: routedRequest)
        case .local(let routedRequest):
            return try await localService.createChatCompletionStream(request: routedRequest)
        }
    }

    private func makeRoutingContext() -> MixlRoutingContext {
        // An injected local service governs its own availability, so report local as available and
        // let that service decide. Otherwise, consult the on-device Foundation Models availability.
        let reason = localServiceInjected ? nil : LocalModelSupport.unavailabilityReason()
        return MixlRoutingContext(
            isLocalAvailable: reason == nil,
            localUnavailabilityReason: reason
        )
    }
}
