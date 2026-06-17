import Foundation

/// Reasons the on-device Foundation Model may be unavailable.
///
/// Returned by ``LocalModelSupport/unavailabilityReason()`` and embedded in
/// ``MixlError/localModelUnavailable(reason:message:)``. Use ``LocalModelSupport/message(for:)``
/// for user-facing copy.
///
/// ## Recovery
///
/// | Case | Typical action |
/// | --- | --- |
/// | ``deviceNotEligible`` | Route to ``MixLayerClient`` or disable on-device features. |
/// | ``appleIntelligenceNotEnabled`` | Prompt the user to enable Apple Intelligence in Settings. |
/// | ``modelNotReady`` | Retry after on-device model assets finish downloading. |
/// | ``frameworkNotAvailable`` | Build or run with Xcode 26+ on a supported OS; CI without Foundation Models always hits this. |
/// | ``unknown`` | Log, retry, or fall back to cloud inference. |
public enum LocalModelUnavailabilityReason: String, Sendable, Equatable {
    /// The device hardware does not support Apple Intelligence on-device models.
    case deviceNotEligible

    /// Apple Intelligence is turned off in Settings.
    case appleIntelligenceNotEnabled

    /// The on-device model assets are still downloading or otherwise not ready.
    case modelNotReady

    /// The Foundation Models framework is not linked in this build (for example, CI on macOS 14).
    case frameworkNotAvailable

    /// The model is unavailable for a reason not mapped by Mixl.
    case unknown
}
