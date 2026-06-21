import Foundation

// MARK: - Fallback Router

/// A router that automatically falls back to a cloud model if a local routing decision fails due to local unavailability.
public final class MixlFallbackRouter: MixlRouter {
    private let primaryRouter: any MixlRouter
    private let fallbackCloudModel: Model

    /// Initializes a fallback router.
    ///
    /// - Parameters:
    ///   - primary: The primary router to consult. Defaults to ``MixlDefaultRouter``.
    ///   - fallbackCloudModel: The cloud model to fall back to if local is unavailable. Defaults to ``Model/qwen3_5_4b_free``.
    public init(
        primary: any MixlRouter = MixlDefaultRouter(),
        fallbackCloudModel: Model = .qwen3_5_4b_free
    ) {
        self.primaryRouter = primary
        self.fallbackCloudModel = fallbackCloudModel
    }

    public func route(request: ChatCompletionRequest, context: MixlRoutingContext) async throws -> MixlRoutingDecision {
        do {
            let decision = try await primaryRouter.route(request: request, context: context)
            switch decision {
            case .local(let localRequest):
                if !context.isLocalAvailable {
                    // Rewrite to fallback cloud model, preserving any payload
                    // transformation the primary router applied to the local request.
                    let fallbackRequest = localRequest.copy(withModel: fallbackCloudModel.rawValue)
                    return .cloud(fallbackRequest)
                }
                return .local(localRequest)
            case .cloud:
                return decision
            }
        } catch MixlError.localModelUnavailable {
            let fallbackRequest = request.copy(withModel: fallbackCloudModel.rawValue)
            return .cloud(fallbackRequest)
        }
    }
}
