import Foundation

/// A backend that always fails with a local-model unavailability error (used when Foundation Models is not linked).
struct LocalUnavailableInferenceService: MixlService, Sendable {
    let reason: LocalModelUnavailabilityReason

    func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        throw unavailableError()
    }

    func createChatCompletionStream(request: ChatCompletionRequest) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        throw unavailableError()
    }

    private func unavailableError() -> MixlError {
        .localModelUnavailable(
            reason: reason,
            message: LocalModelSupport.message(for: reason)
        )
    }
}
