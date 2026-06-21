import Foundation

// MARK: - Pattern Router

/// A rule used by ``MixlPatternRouter`` to route requests based on matching regular expressions.
public struct MixlPatternRule: Sendable {
    /// A descriptive name for the rule (e.g. "PII_Email").
    public let name: String
    /// The regular expression pattern to match against.
    public let regex: NSRegularExpression
    /// The routing decision to make if the pattern matches.
    public let decision: @Sendable (ChatCompletionRequest) -> MixlRoutingDecision

    /// Initializes a pattern matching rule.
    ///
    /// - Parameters:
    ///   - name: A descriptive name for the rule.
    ///   - pattern: A regular expression pattern string.
    ///   - options: Regular expression options. Defaults to empty options.
    ///   - decision: A closure that maps the matched request to a routing decision.
    /// - Throws: An error if the regular expression pattern is invalid.
    public init(
        name: String,
        pattern: String,
        options: NSRegularExpression.Options = [],
        decision: @escaping @Sendable (ChatCompletionRequest) -> MixlRoutingDecision
    ) throws {
        self.name = name
        self.regex = try NSRegularExpression(pattern: pattern, options: options)
        self.decision = decision
    }
}

/// A router that evaluates a list of regular expression rules against prompt text.
///
/// Useful for privacy/PII filtering (e.g. routing prompts containing sensitive data strictly to on-device models).
public final class MixlPatternRouter: MixlRouter {
    private let rules: [MixlPatternRule]
    private let defaultRouter: any MixlRouter

    /// Initializes a pattern router.
    ///
    /// - Parameters:
    ///   - rules: An ordered list of regular expression rules to evaluate.
    ///   - defaultRouter: The router to delegate to if no rules match. Defaults to ``MixlDefaultRouter``.
    public init(
        rules: [MixlPatternRule],
        defaultRouter: any MixlRouter = MixlDefaultRouter()
    ) {
        self.rules = rules
        self.defaultRouter = defaultRouter
    }

    public func route(request: ChatCompletionRequest, context: MixlRoutingContext) async throws -> MixlRoutingDecision {
        let promptText = request.messages.compactMap { $0.content }.joined(separator: "\n")
        let range = NSRange(promptText.startIndex..<promptText.endIndex, in: promptText)

        for rule in rules {
            if rule.regex.firstMatch(in: promptText, options: [], range: range) != nil {
                return rule.decision(request)
            }
        }
        return try await defaultRouter.route(request: request, context: context)
    }
}
