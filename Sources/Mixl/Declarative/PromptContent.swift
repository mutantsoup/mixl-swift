import Foundation

/// A piece of a declaratively-composed prompt.
///
/// ``PromptContent`` is the building block of Mixl's SwiftUI-style declarative layer — the analog of
/// SwiftUI's `View`. Leaf components (``System``, ``User``, ``Assistant``, ``ToolReply``), the
/// ``Prompt`` container, raw `Message` values, modifiers, and user-defined ``PromptComponent`` types
/// all conform. Content is composed with the ``PromptBuilder`` result builder and executed with
/// ``MixlClient/run(_:_:)`` / ``MixlClient/stream(_:_:)``.
///
/// This layer is **pure syntactic sugar**: composed content resolves to a ``ChatCompletionRequest``
/// (plus an optional router and transform chain) and runs through the existing ``MixlClient``
/// pipeline. The imperative `chat.create` API is unchanged.
///
/// - Note: ``build(into:)`` is the resolution entry point. Most users never call it directly —
///   they compose leaves and modifiers — but custom leaf components implement it to append messages
///   or tools via ``PromptResolution``.
public protocol PromptContent {
    /// Appends this content's contribution (messages, tools, configuration) into the resolution buffer.
    func build(into resolution: inout PromptResolution)
}

/// The accumulator a ``PromptContent`` tree resolves into before it becomes a ``ChatCompletionRequest``.
///
/// Leaf components add messages and tools through the `append` methods; modifiers (applied by the
/// declarative layer) fill in configuration, routing, and transforms.
public struct PromptResolution {
    /// The conversation messages, in composition order.
    internal var messages: [Message] = []
    /// The tools collected from `.tools` modifiers.
    internal var tools: [Tool] = []
    /// Sampling, reasoning, and response-format overrides, resolved innermost-wins.
    internal var configuration = PromptConfiguration()
    /// A per-prompt router override, if any modifier set one.
    internal var router: (any MixlRouter)?
    /// Per-prompt transforms, appended in modifier order.
    internal var transforms: [any MixlRequestTransform] = []

    /// Creates an empty resolution buffer.
    public init() {}

    /// Appends a message to the resolved conversation.
    public mutating func append(_ message: Message) {
        messages.append(message)
    }

    /// Appends a tool to the resolved request.
    public mutating func append(tool: Tool) {
        tools.append(tool)
    }
}

/// Resolved request configuration. Each field is `nil` until a modifier sets it; the first writer
/// (the innermost modifier) wins, matching the precedence model of Apple's Foundation Models profiles.
internal struct PromptConfiguration {
    var model: Model?
    var thinking: Bool?
    var reasoningEffort: ReasoningEffort?
    var temperature: Double?
    var topP: Double?
    var topK: Int?
    var frequencyPenalty: Double?
    var presencePenalty: Double?
    var repetitionPenalty: Double?
    var maxCompletionTokens: Int?
    var maxTokens: Int?
    var stop: [String]?
    var seed: Int?
    var responseFormat: ResponseFormat?
}

/// A ``PromptContent`` that resolves its inner content and then applies a configuration mutation.
///
/// Produced by the modifier methods on ``PromptContent`` (for example `.temperature(_:)`). Because
/// the inner content resolves *before* the mutation runs, and configuration setters only fill unset
/// fields, the innermost modifier wins.
public struct _ModifiedPrompt<Inner: PromptContent>: PromptContent {
    let inner: Inner
    let apply: @Sendable (inout PromptResolution) -> Void

    public func build(into resolution: inout PromptResolution) {
        inner.build(into: &resolution)
        apply(&resolution)
    }
}

extension PromptContent {
    /// Wraps the content in a ``_ModifiedPrompt`` that applies `transform` after the content resolves.
    internal func modifying(_ transform: @escaping @Sendable (inout PromptResolution) -> Void) -> _ModifiedPrompt<Self> {
        _ModifiedPrompt(inner: self, apply: transform)
    }
}

extension PromptContent {
    /// The messages this content resolves to.
    ///
    /// Useful for previewing or debugging a composed prompt — for example, printing what will be
    /// sent before running it — without performing a request.
    public func resolvedMessages() -> [Message] {
        var resolution = PromptResolution()
        build(into: &resolution)
        return resolution.messages
    }

    /// The tools this content resolves to.
    public func resolvedTools() -> [Tool] {
        var resolution = PromptResolution()
        build(into: &resolution)
        return resolution.tools
    }
}

/// A type-erased ``PromptContent``.
///
/// Used where content must be passed as a concrete value rather than an existential — notably the
/// `content` handed to a ``PromptModifier``, so modifiers can be applied to it.
public struct AnyPromptContent: PromptContent {
    private let _build: (inout PromptResolution) -> Void

    /// Wraps any content value.
    public init(_ content: any PromptContent) {
        self._build = content.build(into:)
    }

    public func build(into resolution: inout PromptResolution) {
        _build(&resolution)
    }
}

/// An array of content resolves each element in order. Lets ``PromptBuilder`` output and
/// ``PromptComponent/body`` be treated as `PromptContent`.
extension Array: PromptContent where Element == any PromptContent {
    public func build(into resolution: inout PromptResolution) {
        for element in self {
            element.build(into: &resolution)
        }
    }
}

/// A result builder that composes ``PromptContent`` with `if`, `switch`, `for`, and availability checks.
///
/// The direct analog of SwiftUI's `@ViewBuilder` and Foundation Models' instruction builders.
@resultBuilder
public enum PromptBuilder {
    public static func buildExpression(_ expression: any PromptContent) -> [any PromptContent] {
        [expression]
    }

    public static func buildExpression(_ expression: [any PromptContent]) -> [any PromptContent] {
        expression
    }

    public static func buildBlock(_ components: [any PromptContent]...) -> [any PromptContent] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [any PromptContent]?) -> [any PromptContent] {
        component ?? []
    }

    public static func buildEither(first component: [any PromptContent]) -> [any PromptContent] {
        component
    }

    public static func buildEither(second component: [any PromptContent]) -> [any PromptContent] {
        component
    }

    public static func buildArray(_ components: [[any PromptContent]]) -> [any PromptContent] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [any PromptContent]) -> [any PromptContent] {
        component
    }
}
