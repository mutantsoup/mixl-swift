import Foundation

/// A transformation applied to a ``ChatCompletionRequest`` before it is routed and submitted.
///
/// A request transform rewrites the request payload independently of *where* it is sent. Where a
/// ``MixlRouter`` answers "which backend?", a ``MixlRequestTransform`` answers "what payload?" —
/// the two are separate concerns and run in sequence inside ``MixlClient``:
///
/// ```
/// request → [transform chain] → router (picks backend) → backend service
/// ```
///
/// A transform is exactly that — **transform-only**: it returns a (possibly modified) request and
/// never selects a backend. Backend selection remains the exclusive responsibility of the configured
/// ``MixlRouter``.
///
/// Typical uses include normalizing voice-transcribed prompts (stripping "umm"/"uhh" filler),
/// search-and-replace redaction of sensitive terms, prompt compression, or injecting a shared
/// system preamble. Because ``process(request:context:)`` is `async` and `throws`, a transform can
/// call out to another service (for example, a fast on-device model to clean up a transcript) or
/// reject a request outright by throwing.
///
/// ## Composition
///
/// ``MixlClient`` accepts an ordered array of transforms and folds the request through them in
/// order — the output of one becomes the input of the next. This keeps individual transforms small
/// and composable rather than requiring a single combined type.
///
/// ## Example
///
/// ```swift
/// let stripFiller = MixlTransform.mapContent { content in
///     content.replacingOccurrences(
///         of: "\\b(um+|uh+)\\b,?\\s*",
///         with: "",
///         options: [.regularExpression, .caseInsensitive]
///     )
/// }
///
/// let client = MixlClient(apiKey: "your-api-key", transforms: [stripFiller])
/// ```
///
/// ## See Also
///
/// - ``MixlTransform``
/// - ``MixlRouter``
public protocol MixlRequestTransform: Sendable {
    /// Transforms an incoming chat completion request before routing.
    ///
    /// - Parameters:
    ///   - request: The request as produced by the caller or the preceding transform in the chain.
    ///   - context: The runtime routing context, including whether on-device inference is available.
    ///     Read it to vary behavior by destination — for example, only redacting data when the
    ///     request is bound for the cloud.
    /// - Returns: The request to hand to the next transform (or the router, if last in the chain).
    /// - Throws: Any error to abort the request before it reaches a backend.
    func process(
        request: ChatCompletionRequest,
        context: MixlRoutingContext
    ) async throws -> ChatCompletionRequest
}

/// A ``MixlRequestTransform`` backed by an inline closure.
///
/// Use ``MixlTransform`` to express a transform without declaring a new type — the sibling of
/// ``MixlLogicRouter`` on the transform side. For the common case of rewriting message text, prefer
/// the ``mapContent(_:)`` convenience.
///
/// ```swift
/// // Full control over the request and routing context.
/// let pinTemperature = MixlTransform { request, _ in
///     request.copy(withMessages: request.messages) // ...build any modified request
/// }
///
/// // Just rewrite the text of every message.
/// let redact = MixlTransform.mapContent { $0.replacingOccurrences(of: "Project Cerberus", with: "[REDACTED]") }
/// ```
public final class MixlTransform: MixlRequestTransform {
    private let transform: @Sendable (ChatCompletionRequest, MixlRoutingContext) async throws -> ChatCompletionRequest

    /// Creates a transform from a closure.
    ///
    /// - Parameter transform: A closure that maps the request (and routing context) to a new request.
    ///   The closure is `async` and `throws`, so it may perform external work or reject the request.
    public init(
        _ transform: @escaping @Sendable (ChatCompletionRequest, MixlRoutingContext) async throws -> ChatCompletionRequest
    ) {
        self.transform = transform
    }

    public func process(
        request: ChatCompletionRequest,
        context: MixlRoutingContext
    ) async throws -> ChatCompletionRequest {
        try await transform(request, context)
    }

    /// Creates a transform that rewrites the text content of every message.
    ///
    /// Messages with `nil` content (such as assistant tool-call messages) are passed through
    /// unchanged; all other fields — role, name, reasoning content, tool calls — are preserved.
    /// This is the most common transform shape: filler-word removal, term redaction, casing, etc.
    ///
    /// - Parameter transform: A closure mapping each message's content string to its replacement.
    /// - Returns: A ``MixlTransform`` that applies `transform` to every message's content.
    public static func mapContent(
        _ transform: @escaping @Sendable (String) -> String
    ) -> MixlTransform {
        MixlTransform { request, _ in
            request.mappingContent(transform)
        }
    }
}
