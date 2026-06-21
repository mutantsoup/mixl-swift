import Foundation

// MARK: - Common Pattern Rules

/// A starter set of best-effort rules for routing prompts that contain common
/// categories of sensitive data (PII).
///
/// Each factory returns a ready-made ``MixlPatternRule`` and only asks the caller for
/// the routing `decision` (e.g. force matches to an on-device model). The patterns are
/// compile-time constants validated by the test suite, so these factories are
/// non-throwing — unlike ``MixlPatternRule/init(name:pattern:options:decision:)``,
/// which stays throwing for custom user patterns.
///
/// > Important: Regular-expression detection is approximate. These rules favor catching
/// > sensitive data (so it can be kept local) over precision, and may produce false
/// > positives or miss exotic formats. They do **not** perform semantic validation
/// > (for example, no Luhn check on card numbers). Treat them as a gate, not a guarantee.
extension MixlPatternRule {
    /// Matches email addresses, e.g. `jane.doe+tag@sub.example.co.uk`.
    public static func email(
        name: String = "PII_Email",
        decision: @escaping @Sendable (ChatCompletionRequest) -> MixlRoutingDecision
    ) -> MixlPatternRule {
        make(
            name,
            #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            [.caseInsensitive],
            decision
        )
    }

    /// Matches hyphenated US Social Security Numbers, e.g. `123-45-6789`.
    ///
    /// Only the dashed form is matched; bare nine-digit runs are intentionally excluded
    /// to avoid matching ordinary numbers.
    public static func usSSN(
        name: String = "PII_US_SSN",
        decision: @escaping @Sendable (ChatCompletionRequest) -> MixlRoutingDecision
    ) -> MixlPatternRule {
        make(name, #"\b\d{3}-\d{2}-\d{4}\b"#, [], decision)
    }

    /// Matches Visa, Mastercard, American Express, and Discover card numbers, with or
    /// without spaces/hyphens between digit groups (e.g. `4111 1111 1111 1111`).
    ///
    /// No Luhn checksum validation is performed.
    public static func creditCard(
        name: String = "PII_Credit_Card",
        decision: @escaping @Sendable (ChatCompletionRequest) -> MixlRoutingDecision
    ) -> MixlPatternRule {
        make(
            name,
            #"\b(?:4[0-9]{3}(?:[ -]?[0-9]{4}){3}|(?:5[1-5][0-9]{2}|6011)(?:[ -]?[0-9]{4}){3}|3[47][0-9]{2}[ -]?[0-9]{6}[ -]?[0-9]{5})\b"#,
            [],
            decision
        )
    }

    /// Matches North American (US/Canada) phone numbers, with optional `+1` country
    /// code and common separators, e.g. `(415) 555-2671`, `415-555-2671`, `+1 415 555 2671`.
    public static func phoneUS(
        name: String = "PII_US_Phone",
        decision: @escaping @Sendable (ChatCompletionRequest) -> MixlRoutingDecision
    ) -> MixlPatternRule {
        make(
            name,
            #"(?<!\d)(?:\+?1[ .\-]?)?\(?\d{3}\)?[ .\-]?\d{3}[ .\-]?\d{4}(?!\d)"#,
            [],
            decision
        )
    }

    /// Matches octet-validated IPv4 addresses (each group `0`–`255`), e.g. `192.168.0.1`.
    public static func ipv4(
        name: String = "IPv4_Address",
        decision: @escaping @Sendable (ChatCompletionRequest) -> MixlRoutingDecision
    ) -> MixlPatternRule {
        make(
            name,
            #"\b(?:(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b"#,
            [],
            decision
        )
    }

    /// Constructs a rule from a built-in, compile-time-constant pattern. A malformed
    /// built-in pattern is a programmer error (caught by tests), so it traps loudly
    /// rather than forcing every call site to handle a `throws` that cannot happen.
    private static func make(
        _ name: String,
        _ pattern: String,
        _ options: NSRegularExpression.Options,
        _ decision: @escaping @Sendable (ChatCompletionRequest) -> MixlRoutingDecision
    ) -> MixlPatternRule {
        do {
            return try MixlPatternRule(name: name, pattern: pattern, options: options, decision: decision)
        } catch {
            fatalError("Built-in MixlPatternRule '\(name)' has an invalid pattern: \(error)")
        }
    }
}
