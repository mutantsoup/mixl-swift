import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
struct LocalInferenceService: MixlService, Sendable {
    func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        let prepared = try LocalRequestSanitizer.prepare(request)
        try LocalModelSupport.requireAvailable()

        let built = try buildPrompt(from: prepared.messages)
        let options = makeGenerationOptions(from: prepared)
        let session = makeSession(instructions: built.instructions)
        let response = try await session.respond(to: built.prompt, options: options)

        return ChatCompletionResponse(
            id: makeCompletionID(),
            object: "chat.completion",
            created: currentTimestamp(),
            model: request.model,
            choices: [
                .init(
                    index: 0,
                    message: .assistant(response.content),
                    finishReason: "stop"
                )
            ],
            usage: nil
        )
    }

    func createChatCompletionStream(request: ChatCompletionRequest) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let prepared = try LocalRequestSanitizer.prepare(request)
        try LocalModelSupport.requireAvailable()

        let built = try buildPrompt(from: prepared.messages)
        let options = makeGenerationOptions(from: prepared)
        let completionID = makeCompletionID()
        let model = prepared.model
        let created = currentTimestamp()

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = makeSession(instructions: built.instructions)
                    var previousContent = ""
                    let stream = session.streamResponse(to: built.prompt, options: options)

                    for try await partial in stream {
                        if Task.isCancelled {
                            break
                        }
                        let aggregated = partial.content
                        let delta = String(aggregated.dropFirst(previousContent.count))
                        previousContent = aggregated

                        guard !delta.isEmpty else { continue }

                        continuation.yield(
                            makeChunk(
                                id: completionID,
                                created: created,
                                model: model,
                                deltaContent: delta,
                                finishReason: nil
                            )
                        )
                    }

                    continuation.yield(
                        makeChunk(
                            id: completionID,
                            created: created,
                            model: model,
                            deltaContent: nil,
                            finishReason: "stop"
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapInferenceError(error))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func buildPrompt(from messages: [Message]) throws -> LocalPromptBuilder.BuiltPrompt {
        do {
            return try LocalPromptBuilder.build(from: messages)
        } catch LocalPromptBuilder.Error.unsupportedToolMessages {
            throw MixlError.unsupportedParameter("tool messages")
        } catch LocalPromptBuilder.Error.emptyMessages {
            throw MixlError.decodingFailed("messages must not be empty")
        } catch LocalPromptBuilder.Error.missingUserMessage {
            throw MixlError.decodingFailed("messages must include at least one user message")
        }
    }

    private func makeSession(instructions: String?) -> LanguageModelSession {
        if let instructions, !instructions.isEmpty {
            return LanguageModelSession(instructions: instructions)
        }
        return LanguageModelSession()
    }

    private func makeGenerationOptions(from request: ChatCompletionRequest) -> GenerationOptions {
        var options = GenerationOptions()
        if let temperature = request.temperature {
            options.temperature = temperature
        }
        if let maxCompletionTokens = request.maxCompletionTokens ?? request.maxTokens {
            options.maximumResponseTokens = maxCompletionTokens
        }
        return options
    }

    private func makeCompletionID() -> String {
        "chatcmpl-local-\(UUID().uuidString.lowercased())"
    }

    private func currentTimestamp() -> Int {
        Int(Date().timeIntervalSince1970)
    }

    private func makeChunk(
        id: String,
        created: Int,
        model: String,
        deltaContent: String?,
        finishReason: String?
    ) -> ChatCompletionChunk {
        ChatCompletionChunk(
            id: id,
            object: "chat.completion.chunk",
            created: created,
            model: model,
            choices: [
                .init(
                    index: 0,
                    delta: .init(content: deltaContent),
                    finishReason: finishReason
                )
            ]
        )
    }

    private func mapInferenceError(_ error: Error) -> MixlError {
        if let mixlError = error as? MixlError {
            return mixlError
        }
        return .localInferenceFailed(error.localizedDescription)
    }
}

#endif
