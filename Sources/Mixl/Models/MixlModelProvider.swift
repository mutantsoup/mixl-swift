import Foundation

/// Identifies which inference backend should execute requests for a ``Model`` identifier.
///
/// Use ``Model/provider`` to route requests in application code today, or in a future
/// ``MixlService`` orchestrator that selects ``MixLayerClient`` vs ``LocalClient``.
///
/// ## Overview
///
/// | ``MixlModelProvider`` | Client | Example identifier |
/// | --- | --- | --- |
/// | ``mixLayerCloud`` | ``MixLayerClient`` | `qwen/qwen3.5-4b-free` |
/// | ``appleFoundation`` | ``LocalClient`` | `apple/foundation` |
///
/// ## See Also
///
/// - ``Model/appleFoundation``
/// - ``Model/provider``
/// - ``MixlService``
/// - <doc:LocalInference>
public enum MixlModelProvider: String, Sendable, Equatable {
    /// MixLayer cloud models (`qwen/...` identifiers).
    ///
    /// Served by ``MixLayerClient`` over HTTPS to `models.mixlayer.ai`.
    case mixLayerCloud

    /// Apple on-device Foundation Models (`apple/...` identifiers).
    ///
    /// Served by ``LocalClient`` through the Foundation Models framework. Requires iOS 26+,
    /// macOS 26+, and Apple Intelligence availability.
    case appleFoundation
}

extension Model {
    /// Apple’s default on-device Foundation Model (`SystemLanguageModel.default`).
    ///
    /// Pass this identifier to ``LocalClient`` via ``MixlChatCompletionsService`` (`create` or
    /// `createStream`). The raw value sent in requests is `"apple/foundation"`.
    ///
    /// - Note: Do not pass ``appleFoundation`` to ``MixLayerClient``—MixLayer cloud endpoints do not
    ///   serve this identifier. Use a Qwen ``Model`` constant instead.
    public static let appleFoundation = Model(rawValue: "apple/foundation")

    /// The backend that should execute requests for this model identifier.
    ///
    /// Identifiers prefixed with `apple/` map to ``MixlModelProvider/appleFoundation``; all other
    /// identifiers map to ``MixlModelProvider/mixLayerCloud``.
    ///
    /// ```swift
    /// switch model.provider {
    /// case .mixLayerCloud:
    ///     // use MixLayerClient
    /// case .appleFoundation:
    ///     // use LocalClient
    /// }
    /// ```
    public var provider: MixlModelProvider {
        if rawValue.hasPrefix("apple/") {
            return .appleFoundation
        }
        return .mixLayerCloud
    }

    /// Whether this identifier targets Apple’s on-device Foundation Model.
    ///
    /// Equivalent to `provider == .appleFoundation`.
    public var isAppleFoundation: Bool {
        provider == .appleFoundation
    }
}
