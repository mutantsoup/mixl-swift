import Foundation

/// The shared inference protocol implemented by Mixl's cloud and local backends.
///
/// ``MixLayerClient`` uses an internal URLSession-based backend (production) or an injected
/// ``MixlService`` test double. ``LocalClient`` uses a Foundation Models adapter. Both clients
/// expose the same ``MixlChatCompletionsService`` surface through this protocol.
///
/// Conform to ``MixlService`` to provide custom backends or test doubles. A future orchestrator
/// will accept any ``MixlService`` implementation when routing by ``Model/provider``.
///
/// ## See Also
///
/// - ``MixLayerClient``
/// - ``LocalClient``
/// - <doc:LocalInference>
public protocol MixlService: Sendable {
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
