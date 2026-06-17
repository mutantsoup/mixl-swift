import Foundation
import Mixl

/// A thread-safe mock implementation of `MixlService` for unit tests and previews.
public actor MockMixlService: MixlService {
    /// The most recent chat completion request received by the mock.
    public var lastRequest: ChatCompletionRequest?

    /// The response returned from ``createChatCompletion(request:)`` when no error is stubbed.
    public var stubbedResponse: ChatCompletionResponse?

    /// The error thrown from service methods when set.
    public var stubbedError: Error?

    /// Chunks yielded from ``createChatCompletionStream(request:)`` when no error is stubbed.
    public var stubbedStreamChunks: [ChatCompletionChunk]?

    /// Creates a new mock service with empty stub state.
    public init() {}

    /// Sets the response returned by non-streaming completion requests.
    public func setStubbedResponse(_ response: ChatCompletionResponse) {
        self.stubbedResponse = response
    }

    /// Sets the error thrown by service methods.
    public func setStubbedError(_ error: Error) {
        self.stubbedError = error
    }

    /// Sets the chunks emitted by streaming completion requests.
    public func setStubbedStreamChunks(_ chunks: [ChatCompletionChunk]) {
        self.stubbedStreamChunks = chunks
    }

    public func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        lastRequest = request
        if let error = stubbedError {
            throw error
        }
        if let response = stubbedResponse {
            return response
        }
        throw MockMixlServiceError.noStubbedResponse
    }

    public func createChatCompletionStream(
        request: ChatCompletionRequest
    ) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        lastRequest = request
        if let error = stubbedError {
            throw error
        }

        let chunks = stubbedStreamChunks ?? []
        return AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

/// Errors thrown when a mock service is invoked without required stub configuration.
public enum MockMixlServiceError: Error, Sendable, Equatable {
    /// No stubbed response or error was configured for a non-streaming request.
    case noStubbedResponse
}
