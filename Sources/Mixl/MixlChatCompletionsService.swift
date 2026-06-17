import Foundation

/// Shared chat completions API for the Mixl framework.
///
/// Access through ``MixLayerClient/chat`` or ``LocalClient/chat``. Method signatures are identical;
/// supported parameters depend on the active backend—see <doc:LocalInference> for the local
/// compatibility matrix.
public struct MixlChatCompletionsService: Sendable {
    private let service: any MixlService

    internal init(service: any MixlService) {
        self.service = service
    }

    /// Creates a non-streaming chat completion request.
    ///
    /// When called on ``LocalClient``, pass ``Model/appleFoundation``. Cloud-only sampling and
    /// reasoning parameters are stripped with an `os.Logger` message; `tools`, JSON
    /// `response_format`, and tool messages throw ``MixlError/unsupportedParameter(_:)``.
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
    ///
    /// On ``LocalClient``, streams Foundation Models output as ``ChatCompletionChunk`` deltas.
    /// Reasoning content is not emitted on the local path.
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
