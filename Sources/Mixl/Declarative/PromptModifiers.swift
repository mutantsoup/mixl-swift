import Foundation

// MARK: - Configuration modifiers

/// SwiftUI-style modifiers that configure a prompt. Each returns modified content, so they chain.
///
/// Precedence follows Apple's Foundation Models profiles: the **innermost** modifier wins (a
/// configuration field is only filled if not already set), and the `baseModel` passed to
/// ``MixlClient/run(_:_:)`` acts as the lowest-priority default.
extension PromptContent {
    /// Sets the model. Overrides the `baseModel` passed to `run` / `stream`; innermost wins.
    public func model(_ model: Model) -> some PromptContent {
        modifying { $0.configuration.model = $0.configuration.model ?? model }
    }

    /// Enables or disables chain-of-thought reasoning (MixLayer `thinking`).
    public func thinking(_ enabled: Bool = true) -> some PromptContent {
        modifying { $0.configuration.thinking = $0.configuration.thinking ?? enabled }
    }

    /// Sets the OpenAI-compatible `reasoning_effort` level. The analog of Foundation Models'
    /// `.reasoningLevel(_:)`; Mixl keeps the wire-level `.low` / `.medium` / `.high` values.
    public func reasoning(_ effort: ReasoningEffort) -> some PromptContent {
        modifying { $0.configuration.reasoningEffort = $0.configuration.reasoningEffort ?? effort }
    }

    /// Sets the sampling temperature (0.0–2.0).
    public func temperature(_ value: Double) -> some PromptContent {
        modifying { $0.configuration.temperature = $0.configuration.temperature ?? value }
    }

    /// Sets the nucleus-sampling threshold (`top_p`).
    public func topP(_ value: Double) -> some PromptContent {
        modifying { $0.configuration.topP = $0.configuration.topP ?? value }
    }

    /// Sets the top-K sampling cutoff.
    public func topK(_ value: Int) -> some PromptContent {
        modifying { $0.configuration.topK = $0.configuration.topK ?? value }
    }

    /// Sets the frequency penalty.
    public func frequencyPenalty(_ value: Double) -> some PromptContent {
        modifying { $0.configuration.frequencyPenalty = $0.configuration.frequencyPenalty ?? value }
    }

    /// Sets the presence penalty.
    public func presencePenalty(_ value: Double) -> some PromptContent {
        modifying { $0.configuration.presencePenalty = $0.configuration.presencePenalty ?? value }
    }

    /// Sets the repetition penalty.
    public func repetitionPenalty(_ value: Double) -> some PromptContent {
        modifying { $0.configuration.repetitionPenalty = $0.configuration.repetitionPenalty ?? value }
    }

    /// Sets the maximum number of completion tokens to generate.
    public func maxCompletionTokens(_ value: Int) -> some PromptContent {
        modifying { $0.configuration.maxCompletionTokens = $0.configuration.maxCompletionTokens ?? value }
    }

    /// Sets the legacy `max_tokens` value.
    public func maxTokens(_ value: Int) -> some PromptContent {
        modifying { $0.configuration.maxTokens = $0.configuration.maxTokens ?? value }
    }

    /// Sets the best-effort deterministic sampling seed.
    public func seed(_ value: Int) -> some PromptContent {
        modifying { $0.configuration.seed = $0.configuration.seed ?? value }
    }

    /// Sets the stop sequences.
    public func stop(_ sequences: [String]) -> some PromptContent {
        modifying { $0.configuration.stop = $0.configuration.stop ?? sequences }
    }

    /// Sets the stop sequences.
    public func stop(_ sequences: String...) -> some PromptContent {
        stop(sequences)
    }

    /// Sets the response format (text, JSON object, or JSON schema).
    public func responseFormat(_ format: ResponseFormat) -> some PromptContent {
        modifying { $0.configuration.responseFormat = $0.configuration.responseFormat ?? format }
    }
}

// MARK: - Tools

extension PromptContent {
    /// Appends tools to the request. Accumulates across modifiers.
    public func tools(_ tools: [Tool]) -> some PromptContent {
        modifying { $0.tools.append(contentsOf: tools) }
    }
}

// MARK: - Routing & transform modifiers (bridge to MixlRouter / MixlRequestTransform)

extension PromptContent {
    /// Overrides the routing policy for this prompt. The first router set (innermost) wins; if none
    /// is set, the ``MixlClient``'s configured router is used.
    public func router(_ router: any MixlRouter) -> some PromptContent {
        modifying { $0.router = $0.router ?? router }
    }

    /// Routes through a ``MixlFallbackRouter`` that falls back to `model` in the cloud when on-device
    /// inference is unavailable.
    public func fallback(to model: Model) -> some PromptContent {
        router(MixlFallbackRouter(fallbackCloudModel: model))
    }

    /// Appends a request transform applied before routing. Composes with the ``MixlClient``'s
    /// configured transforms (client transforms run first, then per-prompt transforms).
    public func transform(_ transform: any MixlRequestTransform) -> some PromptContent {
        modifying { $0.transforms.append(transform) }
    }

    /// Appends an inline closure transform.
    public func transform(
        _ body: @escaping @Sendable (ChatCompletionRequest, MixlRoutingContext) async throws -> ChatCompletionRequest
    ) -> some PromptContent {
        transform(MixlTransform(body))
    }

    /// Appends a content-rewriting transform over every message's text.
    public func mapContent(_ body: @escaping @Sendable (String) -> String) -> some PromptContent {
        transform(MixlTransform.mapContent(body))
    }
}

// MARK: - Custom modifiers

/// A reusable, named modifier — the analog of SwiftUI's `ViewModifier` and Foundation Models'
/// `DynamicProfileModifier`.
///
/// Conform a type, compose `body(content:)` from the incoming content plus other modifiers, then
/// expose it with a convenience method:
///
/// ```swift
/// struct Redacting: PromptModifier {
///     let term: String
///     func body(content: AnyPromptContent) -> some PromptContent {
///         content.mapContent { $0.replacingOccurrences(of: term, with: "[REDACTED]") }
///     }
/// }
///
/// extension PromptContent {
///     func redact(_ term: String) -> some PromptContent { modifier(Redacting(term: term)) }
/// }
/// ```
public protocol PromptModifier {
    associatedtype Body: PromptContent
    /// Produces new content from the (type-erased) content the modifier is applied to.
    func body(content: AnyPromptContent) -> Body
}

extension PromptContent {
    /// Applies a custom ``PromptModifier``.
    public func modifier<M: PromptModifier>(_ modifier: M) -> some PromptContent {
        modifier.body(content: AnyPromptContent(self))
    }
}
