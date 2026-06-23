import Foundation

/// Declarative execution entry points on ``MixlClient``.
///
/// These resolve composed ``PromptContent`` into a ``ChatCompletionRequest`` (plus any per-prompt
/// router and transforms) and run it through the same routing pipeline as the imperative
/// `chat.create` / `chat.createStream` API. A per-prompt ``PromptContent/router(_:)`` overrides the
/// client's configured router for that call; per-prompt transforms run after the client's configured
/// transforms.
extension MixlClient {
    /// Runs a declaratively-composed prompt and returns the completion.
    ///
    /// `baseModel` is the lowest-priority model default; a `.model(_:)` modifier inside the content
    /// overrides it.
    ///
    /// ```swift
    /// let response = try await client.run(.qwen3_5_27b) {
    ///     System("You are concise.")
    ///     User("Explain routing in one sentence.")
    /// }
    /// ```
    public func run(
        _ baseModel: Model,
        @PromptBuilder _ content: () -> [any PromptContent]
    ) async throws -> ChatCompletionResponse {
        try await run(baseModel, content())
    }

    /// Runs a declaratively-composed prompt value (or ``PromptComponent``) and returns the completion.
    public func run(
        _ baseModel: Model,
        _ prompt: some PromptContent
    ) async throws -> ChatCompletionResponse {
        let (request, router, transforms) = prepare(prompt, baseModel: baseModel, stream: false)
        let decision = try await routeRequest(request, router: router, transforms: transforms)
        return try await dispatch(decision)
    }

    /// Streams a declaratively-composed prompt, yielding chunks as they arrive.
    public func stream(
        _ baseModel: Model,
        @PromptBuilder _ content: () -> [any PromptContent]
    ) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        try await stream(baseModel, content())
    }

    /// Streams a declaratively-composed prompt value (or ``PromptComponent``).
    public func stream(
        _ baseModel: Model,
        _ prompt: some PromptContent
    ) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let (request, router, transforms) = prepare(prompt, baseModel: baseModel, stream: true)
        let decision = try await routeRequest(request, router: router, transforms: transforms)
        return try await dispatchStream(decision)
    }

    /// Resolves composed content into a request plus the effective router and transform chain.
    private func prepare(
        _ prompt: some PromptContent,
        baseModel: Model,
        stream: Bool
    ) -> (ChatCompletionRequest, any MixlRouter, [any MixlRequestTransform]) {
        var resolution = PromptResolution()
        prompt.build(into: &resolution)

        let config = resolution.configuration
        let request = ChatCompletionRequest(
            model: (config.model ?? baseModel).rawValue,
            messages: resolution.messages,
            thinking: config.thinking,
            reasoningEffort: config.reasoningEffort,
            temperature: config.temperature,
            topP: config.topP,
            topK: config.topK,
            frequencyPenalty: config.frequencyPenalty,
            presencePenalty: config.presencePenalty,
            repetitionPenalty: config.repetitionPenalty,
            maxCompletionTokens: config.maxCompletionTokens,
            maxTokens: config.maxTokens,
            stop: config.stop,
            seed: config.seed,
            stream: stream,
            tools: resolution.tools.isEmpty ? nil : resolution.tools,
            responseFormat: config.responseFormat
        )

        let router = resolution.router ?? self.router
        return (request, router, self.transforms + resolution.transforms)
    }
}
