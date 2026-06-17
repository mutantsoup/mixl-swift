import Foundation

/// On-device inference client backed by Apple’s Foundation Models framework.
///
/// ``LocalClient`` exposes the same ``MixlChatCompletionsService`` API shape as ``MixLayerClient``,
/// but does not require a MixLayer API key. Pass ``Model/appleFoundation`` to `chat.create` and
/// `chat.createStream`.
///
/// ## Overview
///
/// Use ``LocalClient`` when you want private, on-device chat completions through Apple Intelligence.
/// Requests are executed by Foundation Models (`LanguageModelSession` / `SystemLanguageModel`) and
/// returned as the same ``ChatCompletionResponse`` and ``ChatCompletionChunk`` types used by the
/// cloud client, so UI and business logic can stay backend-agnostic.
///
/// - Important: ``LocalClient`` requires `@available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)`.
///   Guard call sites with `#available` and preflight with ``LocalModelSupport`` before showing
///   on-device inference UI.
///
/// ## Availability
///
/// Call ``LocalModelSupport/unavailabilityReason()`` before creating a client. If it returns
/// non-`nil`, show ``LocalModelSupport/message(for:)`` to the user or route to ``MixLayerClient``.
///
/// ```swift
/// if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
///     if LocalModelSupport.unavailabilityReason() == nil {
///         let client = LocalClient()
///         // ...
///     }
/// }
/// ```
///
/// ## Example
///
/// ```swift
/// if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
///     try LocalModelSupport.requireAvailable()
///
///     let client = LocalClient()
///     let response = try await client.chat.create(
///         model: .appleFoundation,
///         messages: [
///             .system("You are a helpful assistant."),
///             .user("Explain Mixl in one sentence.")
///         ],
///         temperature: 0.7
///     )
///     print(response.choices.first?.message.content ?? "")
/// }
/// ```
///
/// ## Parameter support
///
/// The local backend supports `temperature`, `maxCompletionTokens` / `maxTokens`, and standard
/// text messages. Cloud-only sampling and reasoning parameters are stripped with an `os.Logger`
/// message; `tools`, JSON `responseFormat`, and tool messages throw ``MixlError/unsupportedParameter(_:)``.
/// See <doc:LocalInference> for the full compatibility matrix.
///
/// ## Testing
///
/// Inject a ``MixlService`` test double through ``init(service:)``. The `MixlTesting` product
/// provides `MockMixlService` for this purpose—the same pattern as
/// ``MixLayerClient/init(apiKey:baseURL:session:service:)``.
///
/// ## See Also
///
/// - ``LocalModelSupport``
/// - ``Model/appleFoundation``
/// - ``MixLayerClient``
/// - <doc:LocalInference>
@available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
public final class LocalClient: Sendable {
    internal let service: any MixlService

    /// Entry point for chat completions endpoints.
    ///
    /// Provides `create` and `createStream` methods with the same signatures as
    /// ``MixLayerClient/chat``. The active backend is determined by ``LocalClient``’s injected
    /// ``MixlService`` implementation (Foundation Models in production, or a mock in tests).
    public var chat: MixlChatCompletionsService {
        MixlChatCompletionsService(service: service)
    }

    /// Creates a client for on-device Foundation Models inference.
    ///
    /// When `service` is `nil`, Mixl uses an internal Foundation Models backend when the
    /// framework is linked, or a stub that throws ``MixlError/localModelUnavailable(reason:message:)``
    /// with ``LocalModelUnavailabilityReason/frameworkNotAvailable`` when it is not (for example,
    /// CI builds on macOS runners without the Xcode 26 SDK).
    ///
    /// - Parameter service: An optional ``MixlService`` implementation to inject for testing
    ///   or custom routing. Defaults to the Foundation Models backend.
    public init(service: (any MixlService)? = nil) {
        #if canImport(FoundationModels)
        self.service = service ?? LocalInferenceService()
        #else
        self.service = service ?? LocalUnavailableInferenceService(reason: .frameworkNotAvailable)
        #endif
    }
}
