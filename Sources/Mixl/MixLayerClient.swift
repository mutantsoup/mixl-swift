import Foundation

/// The primary entry point client for accessing the MixLayer API.
///
/// Use `MixLayerClient` to configure API authentication and host base URLs,
/// and access inference namespaces like `chat`.
public final class MixLayerClient: Sendable {
    /// The API key used to authenticate requests.
    public let apiKey: String

    /// The base server URL for the MixLayer API endpoints.
    public let baseURL: URL

    internal let service: any MixLayerService

    /// Entry point for Chat Completions endpoints.
    public var chat: ChatCompletionsService {
        ChatCompletionsService(service: service)
    }

    /// Initializes a new client instance for the MixLayer API.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for client authentication.
    ///   - baseURL: The base URL of the API. Defaults to `https://models.mixlayer.ai/v1`.
    ///   - session: The `URLSession` used for network requests.
    ///   - service: An optional mock or custom service interface to inject for testing.
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://models.mixlayer.ai/v1")!,
        session: URLSession = .shared,
        service: (any MixLayerService)? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.service = service ?? APIService(apiKey: apiKey, baseURL: baseURL, session: session)
    }
}

/// A service to request chat completions from the MixLayer API.
public struct ChatCompletionsService: Sendable {
    private let service: any MixLayerService

    internal init(service: any MixLayerService) {
        self.service = service
    }

    /// Creates a non-streaming chat completion request.
    public func create(
        model: Model,
        messages: [Message],
        thinking: Bool? = nil,
        reasoningEffort: ReasoningEffort? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        repetitionPenalty: Double? = nil,
        maxCompletionTokens: Int? = nil,
        maxTokens: Int? = nil,
        stop: [String]? = nil,
        seed: Int? = nil,
        tools: [Tool]? = nil,
        responseFormat: ResponseFormat? = nil
    ) async throws -> ChatCompletionResponse {
        let request = makeRequest(
            model: model,
            messages: messages,
            stream: false,
            thinking: thinking,
            reasoningEffort: reasoningEffort,
            temperature: temperature,
            topP: topP,
            topK: topK,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            repetitionPenalty: repetitionPenalty,
            maxCompletionTokens: maxCompletionTokens,
            maxTokens: maxTokens,
            stop: stop,
            seed: seed,
            tools: tools,
            responseFormat: responseFormat
        )
        return try await service.createChatCompletion(request: request)
    }

    /// Creates a streaming chat completion request yielding parts of the response as they are generated.
    public func createStream(
        model: Model,
        messages: [Message],
        thinking: Bool? = nil,
        reasoningEffort: ReasoningEffort? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        repetitionPenalty: Double? = nil,
        maxCompletionTokens: Int? = nil,
        maxTokens: Int? = nil,
        stop: [String]? = nil,
        seed: Int? = nil,
        tools: [Tool]? = nil,
        responseFormat: ResponseFormat? = nil
    ) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let request = makeRequest(
            model: model,
            messages: messages,
            stream: true,
            thinking: thinking,
            reasoningEffort: reasoningEffort,
            temperature: temperature,
            topP: topP,
            topK: topK,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            repetitionPenalty: repetitionPenalty,
            maxCompletionTokens: maxCompletionTokens,
            maxTokens: maxTokens,
            stop: stop,
            seed: seed,
            tools: tools,
            responseFormat: responseFormat
        )
        return try await service.createChatCompletionStream(request: request)
    }

    private func makeRequest(
        model: Model,
        messages: [Message],
        stream: Bool,
        thinking: Bool?,
        reasoningEffort: ReasoningEffort?,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        frequencyPenalty: Double?,
        presencePenalty: Double?,
        repetitionPenalty: Double?,
        maxCompletionTokens: Int?,
        maxTokens: Int?,
        stop: [String]?,
        seed: Int?,
        tools: [Tool]?,
        responseFormat: ResponseFormat?
    ) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: model.rawValue,
            messages: messages,
            thinking: thinking,
            reasoningEffort: reasoningEffort,
            temperature: temperature,
            topP: topP,
            topK: topK,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            repetitionPenalty: repetitionPenalty,
            maxCompletionTokens: maxCompletionTokens,
            maxTokens: maxTokens,
            stop: stop,
            seed: seed,
            stream: stream,
            tools: tools,
            responseFormat: responseFormat
        )
    }
}
