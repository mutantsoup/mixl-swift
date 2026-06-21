import Mixl
import XCTest

@testable import Mixl

final class MixlRouterTests: XCTestCase {

    // MARK: - MixlLogicRouter Tests

    func testLogicRouterRunsAsyncClosure() async throws {
        // Given
        let router = MixlLogicRouter { request, context in
            let totalLength = request.messages.compactMap { $0.content?.count }.reduce(0, +)
            if totalLength < 50 && context.isLocalAvailable {
                return .local(request)
            } else {
                return .cloud(request)
            }
        }

        let request = ChatCompletionRequest(model: "any-model", messages: [.user("Short prompt")])
        let contextAvailable = MixlRoutingContext(isLocalAvailable: true)
        let contextUnavailable = MixlRoutingContext(isLocalAvailable: false)

        // When
        let decision1 = try await router.route(request: request, context: contextAvailable)
        let decision2 = try await router.route(request: request, context: contextUnavailable)

        // Then
        XCTAssertEqual(decision1, .local(request))
        XCTAssertEqual(decision2, .cloud(request))
    }

    // MARK: - MixlPatternRouter Tests

    func testPatternRouterRoutesOnRegexMatch() async throws {
        // Given
        let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let piiRule = try MixlPatternRule(name: "PII_Email", pattern: emailPattern) { request in
            return .local(request.copy(withModel: Model.appleFoundation.rawValue))
        }
        let router = MixlPatternRouter(rules: [piiRule])

        let requestWithEmail = ChatCompletionRequest(model: "default-model", messages: [.user("My contact is support@mixlayer.com")])
        let requestWithoutEmail = ChatCompletionRequest(model: "default-model", messages: [.user("My contact is standard phone number")])

        let context = MixlRoutingContext(isLocalAvailable: true)

        // When
        let decisionWithEmail = try await router.route(request: requestWithEmail, context: context)
        let decisionWithoutEmail = try await router.route(request: requestWithoutEmail, context: context)

        // Then
        // Should route to local and rewrite the model
        XCTAssertEqual(decisionWithEmail, .local(requestWithEmail.copy(withModel: Model.appleFoundation.rawValue)))
        // Should default route (which goes to cloud since default-model is not local)
        XCTAssertEqual(decisionWithoutEmail, .cloud(requestWithoutEmail))
    }

    // MARK: - MixlFallbackRouter Tests

    func testFallbackRouterRedirectsToCloudWhenLocalUnavailable() async throws {
        // Given
        let router = MixlFallbackRouter(fallbackCloudModel: .qwen3_5_27b)
        let localRequest = ChatCompletionRequest(model: Model.appleFoundation.rawValue, messages: [.user("Hello")])

        let contextAvailable = MixlRoutingContext(isLocalAvailable: true)
        let contextUnavailable = MixlRoutingContext(isLocalAvailable: false, localUnavailabilityReason: .deviceNotEligible)

        // When
        let decision1 = try await router.route(request: localRequest, context: contextAvailable)
        let decision2 = try await router.route(request: localRequest, context: contextUnavailable)

        // Then
        XCTAssertEqual(decision1, .local(localRequest))
        XCTAssertEqual(decision2, .cloud(localRequest.copy(withModel: Model.qwen3_5_27b.rawValue)))
    }
}
