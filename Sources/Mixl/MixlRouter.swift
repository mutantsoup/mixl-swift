import Foundation

/// A context structure capturing the runtime state of the local backend.
///
/// Passed to ``MixlRouter/route(request:context:)`` to help make routing decisions.
public struct MixlRoutingContext: Sendable, Equatable {
    /// Whether the local foundation models framework is linked and available to execute requests.
    public let isLocalAvailable: Bool

    /// The specific unavailability reason if local inference is blocked, or `nil` if local inference is available.
    public let localUnavailabilityReason: LocalModelUnavailabilityReason?

    /// Initializes a routing context.
    public init(
        isLocalAvailable: Bool,
        localUnavailabilityReason: LocalModelUnavailabilityReason? = nil
    ) {
        self.isLocalAvailable = isLocalAvailable
        self.localUnavailabilityReason = localUnavailabilityReason
    }
}

/// A decision made by a ``MixlRouter`` describing which backend to target and the payload to submit.
public enum MixlRoutingDecision: Sendable, Equatable {
    /// Submit the given request payload to the MixLayer cloud client.
    case cloud(ChatCompletionRequest)

    /// Submit the given request payload to the local on-device client.
    case local(ChatCompletionRequest)
}

/// A protocol defining how chat completion requests are routed across backends.
///
/// Implement this protocol to define custom routing policies (e.g. cloud fallbacks,
/// latency/cost optimizations, or prompt compression).
public protocol MixlRouter: Sendable {
    /// Determines how a chat completion request should be routed.
    ///
    /// - Parameters:
    ///   - request: The incoming chat completion request payload.
    ///   - context: The runtime system context, including on-device model availability.
    /// - Returns: A routing decision specifying the target backend and request payload.
    func route(
        request: ChatCompletionRequest,
        context: MixlRoutingContext
    ) async throws -> MixlRoutingDecision
}

/// The default routing implementation used by ``MixlClient``.
///
/// Routes `.appleFoundation` requests to the local backend and all other requests to the MixLayer
/// cloud backend. The router is **availability-aware**: when a request explicitly targets the local
/// backend but on-device inference is unavailable (see ``MixlRoutingContext/isLocalAvailable``), it
/// throws ``MixlError/localModelUnavailable(reason:message:)`` rather than routing elsewhere.
///
/// It does **not** silently fall back to the cloud for `.appleFoundation` requests: the MixLayer
/// cloud does not host the `apple/foundation` model, so a backend swap would only surface a more
/// confusing model-not-found error. Implement a custom ``MixlRouter`` if you want availability-based
/// cloud substitution (for example, rewriting the request to a cloud model when local is down).
public struct MixlDefaultRouter: MixlRouter {
    /// Creates a default router instance.
    public init() {}

    /// Routes the request to local when the model is `.appleFoundation` and local inference is
    /// available, throws when local is requested but unavailable, and routes to cloud otherwise.
    public func route(
        request: ChatCompletionRequest,
        context: MixlRoutingContext
    ) async throws -> MixlRoutingDecision {
        let model = Model(rawValue: request.model)
        guard model.isAppleFoundation else {
            return .cloud(request)
        }
        guard context.isLocalAvailable else {
            let reason = context.localUnavailabilityReason ?? .unknown
            throw MixlError.localModelUnavailable(
                reason: reason,
                message: LocalModelSupport.message(for: reason)
            )
        }
        return .local(request)
    }
}
