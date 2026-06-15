import Foundation

/// A protocol defining the service interface for MixLayer API requests.
///
/// Implement this protocol to provide a concrete network provider (e.g. `APIService`)
/// or a test double from the `MixlTesting` product (e.g. ``MockMixLayerService``).
public protocol MixLayerService: Sendable {
    /// Submits a standard chat completion request and returns the decoded response choice.
    ///
    /// - Parameter request: The model configuration and conversation payload parameters.
    /// - Returns: A decoded `ChatCompletionResponse` struct.
    func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse
    
    /// Submits a streaming chat completion request and returns a stream of response chunks.
    ///
    /// - Parameter request: The model configuration and conversation payload parameters.
    /// - Returns: An `AsyncThrowingStream` emitting `ChatCompletionChunk` instances.
    func createChatCompletionStream(request: ChatCompletionRequest) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error>
}
