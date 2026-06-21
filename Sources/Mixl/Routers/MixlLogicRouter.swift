import Foundation

// MARK: - Logic Router

/// A router that executes a custom closure to determine request routing.
///
/// Use ``MixlLogicRouter`` to write inline logic (such as prompt size checks or system status checks)
/// without declaring a new type.
public final class MixlLogicRouter: MixlRouter {
    private let routingLogic: @Sendable (ChatCompletionRequest, MixlRoutingContext) async throws -> MixlRoutingDecision

    /// Initializes a logic-based router with a custom routing closure.
    ///
    /// - Parameter routingLogic: A closure that evaluates the request and routing context and returns a decision.
    public init(
        routingLogic: @escaping @Sendable (ChatCompletionRequest, MixlRoutingContext) async throws -> MixlRoutingDecision
    ) {
        self.routingLogic = routingLogic
    }

    public func route(request: ChatCompletionRequest, context: MixlRoutingContext) async throws -> MixlRoutingDecision {
        try await routingLogic(request, context)
    }
}
