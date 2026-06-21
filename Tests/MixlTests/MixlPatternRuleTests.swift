import Mixl
import XCTest

@testable import Mixl

final class MixlPatternRuleCommonTests: XCTestCase {

    // MARK: - Helpers

    /// Routes any match to local; used purely so the factories have a decision closure.
    private let toLocal: @Sendable (ChatCompletionRequest) -> MixlRoutingDecision = { request in
        .local(request.copy(withModel: Model.appleFoundation.rawValue))
    }

    /// Returns whether the rule's compiled regex matches anywhere in `text`.
    private func matches(_ rule: MixlPatternRule, _ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return rule.regex.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Asserts the rule matches every positive and none of the negative samples.
    private func assertRule(
        _ rule: MixlPatternRule,
        matches positives: [String],
        rejects negatives: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for sample in positives {
            XCTAssertTrue(matches(rule, sample), "Expected \(rule.name) to match: \(sample)", file: file, line: line)
        }
        for sample in negatives {
            XCTAssertFalse(matches(rule, sample), "Expected \(rule.name) NOT to match: \(sample)", file: file, line: line)
        }
    }

    // MARK: - Email

    func testEmailRule() {
        let rule = MixlPatternRule.email(decision: toLocal)
        assertRule(
            rule,
            matches: [
                "support@mixlayer.com",
                "Contact jane.doe+tag@sub.example.co.uk please",
                "UPPER.CASE@EXAMPLE.IO",
                "a_b-c%d@host-name.org"
            ],
            rejects: [
                "no email here",
                "not-an-email@",
                "@missing-local.com",
                "missing-tld@host"
            ]
        )
    }

    // MARK: - US SSN

    func testUSSSNRule() {
        let rule = MixlPatternRule.usSSN(decision: toLocal)
        assertRule(
            rule,
            matches: [
                "123-45-6789",
                "My SSN is 001-23-4567.",
                "tax id 555-44-3333 on file"
            ],
            rejects: [
                "123456789",          // no dashes — intentionally excluded
                "12-345-6789",        // wrong grouping
                "1234-56-7890",       // wrong grouping
                "no ssn here"
            ]
        )
    }

    // MARK: - Credit Card

    func testCreditCardRule() {
        let rule = MixlPatternRule.creditCard(decision: toLocal)
        assertRule(
            rule,
            matches: [
                "4111111111111111",          // Visa, contiguous
                "4111 1111 1111 1111",       // Visa, spaced
                "5500-0000-0000-0004",       // Mastercard, hyphenated
                "6011 1111 1111 1117",       // Discover
                "card: 378282246310005",     // Amex, contiguous (15 digits)
                "3782 822463 10005"          // Amex, grouped
            ],
            rejects: [
                "1234 5678",                 // too short
                "(415) 555-2671",            // phone, not a card
                "1234567890123456",          // 16 digits but invalid prefix
                "no card here"
            ]
        )
    }

    // MARK: - US Phone

    func testPhoneUSRule() {
        let rule = MixlPatternRule.phoneUS(decision: toLocal)
        assertRule(
            rule,
            matches: [
                "(415) 555-2671",
                "415-555-2671",
                "+1 415 555 2671",
                "Call 415.555.2671 today",
                "4155552671"
            ],
            rejects: [
                "12345",                     // too short
                "4111111111111111",          // 16-digit card, not a 10-digit phone
                "123-45-6789",               // SSN grouping
                "no phone here"
            ]
        )
    }

    // MARK: - IPv4

    func testIPv4Rule() {
        let rule = MixlPatternRule.ipv4(decision: toLocal)
        assertRule(
            rule,
            matches: [
                "192.168.0.1",
                "10.0.0.255",
                "255.255.255.255",
                "server at 172.16.254.1 responded"
            ],
            rejects: [
                "256.1.1.1",                 // octet out of range
                "999.999.999.999",
                "1.2.3",                     // too few octets
                "no ip here"
            ]
        )
    }

    // MARK: - Decision wiring

    func testFactoryWiresDecisionClosure() {
        let request = ChatCompletionRequest(model: "default-model", messages: [.user("x")])
        let rule = MixlPatternRule.email { req in
            .cloud(req.copy(withModel: Model.qwen3_5_27b.rawValue))
        }
        let decision = rule.decision(request)
        XCTAssertEqual(decision, .cloud(request.copy(withModel: Model.qwen3_5_27b.rawValue)))
        XCTAssertEqual(rule.name, "PII_Email")
    }

    func testCustomRuleNameIsRespected() {
        let rule = MixlPatternRule.usSSN(name: "Custom_SSN", decision: toLocal)
        XCTAssertEqual(rule.name, "Custom_SSN")
    }

    // MARK: - Built-in patterns all compile

    /// Guards the non-throwing factories: constructing every built-in rule would trap
    /// via `fatalError` if any packaged pattern were malformed.
    func testAllBuiltInRulesConstruct() {
        let rules = [
            MixlPatternRule.email(decision: toLocal),
            MixlPatternRule.usSSN(decision: toLocal),
            MixlPatternRule.creditCard(decision: toLocal),
            MixlPatternRule.phoneUS(decision: toLocal),
            MixlPatternRule.ipv4(decision: toLocal)
        ]
        XCTAssertEqual(rules.count, 5)
        XCTAssertEqual(Set(rules.map { $0.name }).count, 5, "Built-in rule names should be unique")
    }

    // MARK: - Integration with MixlPatternRouter

    func testRouterUsesCommonRuleAndFallsBackToDefault() async throws {
        // Given: route any prompt containing an email to local, otherwise default (cloud).
        let router = MixlPatternRouter(rules: [MixlPatternRule.email(decision: toLocal)])
        let context = MixlRoutingContext(isLocalAvailable: true)

        let withEmail = ChatCompletionRequest(model: "default-model", messages: [.user("reach me at a@b.com")])
        let withoutEmail = ChatCompletionRequest(model: "default-model", messages: [.user("reach me by phone")])

        // When
        let matched = try await router.route(request: withEmail, context: context)
        let unmatched = try await router.route(request: withoutEmail, context: context)

        // Then
        XCTAssertEqual(matched, .local(withEmail.copy(withModel: Model.appleFoundation.rawValue)))
        XCTAssertEqual(unmatched, .cloud(withoutEmail)) // default router -> cloud for non-local model
    }
}
