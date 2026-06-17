import Foundation

/// Utilities for checking whether Apple’s on-device Foundation Model can run.
///
/// Use ``LocalModelSupport`` to preflight ``LocalClient`` usage without attempting inference.
/// It wraps Foundation Models `SystemLanguageModel.default.availability` when the framework
/// is linked, and reports ``LocalModelUnavailabilityReason/frameworkNotAvailable`` otherwise.
///
/// ## Overview
///
/// Mixl separates **unsupported** requests from **unavailable** devices:
///
/// - **Unsupported:** wrong model for ``LocalClient`` (``MixlError/modelNotSupported(model:backend:)``)
///   or semantic local parameters (``MixlError/unsupportedParameter(_:)`` for `tools`, JSON
///   `response_format`, and tool messages).
/// - **Unavailable:** correct client configuration, but Apple Intelligence or the on-device model
///   cannot run (``MixlError/localModelUnavailable(reason:message:)``).
///
/// ## Example
///
/// ```swift
/// if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
///     switch LocalModelSupport.unavailabilityReason() {
///     case nil:
///         let client = LocalClient()
///         // ready for inference
///     case .appleIntelligenceNotEnabled:
///         // prompt user to enable Apple Intelligence in Settings
///         break
///     case let reason?:
///         print(LocalModelSupport.message(for: reason))
///     }
/// }
/// ```
///
/// ## See Also
///
/// - ``LocalClient``
/// - ``LocalModelUnavailabilityReason``
/// - ``MixlError/localModelUnavailable(reason:message:)``
/// - <doc:LocalInference>
public enum LocalModelSupport {
    /// Whether the Foundation Models framework is linked in this build.
    ///
    /// Returns `false` on build environments without the Xcode 26 SDK (for example, GitHub Actions
    /// runners that compile Mixl without Foundation Models). In that case ``LocalClient`` still
    /// compiles but its default backend throws ``LocalModelUnavailabilityReason/frameworkNotAvailable``.
    public static var isFrameworkAvailable: Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }

    /// Returns the unavailability reason when the local model cannot run, or `nil` when inference should succeed.
    ///
    /// Call this before constructing a ``LocalClient`` if you want to show UI or choose a fallback
    /// backend without paying the cost of a failed inference attempt.
    ///
    /// - Returns: `nil` when ``LocalClient`` should be able to run ``Model/appleFoundation`` requests,
    ///   or a ``LocalModelUnavailabilityReason`` describing why on-device inference is blocked.
    public static func unavailabilityReason() -> LocalModelUnavailabilityReason? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            return LocalModelAvailability.unavailabilityReason()
        }
        return .frameworkNotAvailable
        #else
        return .frameworkNotAvailable
        #endif
    }

    /// A human-readable explanation for a ``LocalModelUnavailabilityReason``.
    ///
    /// Suitable for alert messages, settings deep links, or logging. The string is stable for
    /// display but not for programmatic branching—compare ``LocalModelUnavailabilityReason`` values instead.
    ///
    /// - Parameter reason: The reason returned by ``unavailabilityReason()`` or
    ///   ``MixlError/localModelUnavailable(reason:message:)``.
    /// - Returns: A localized-style English message describing the unavailability condition.
    public static func message(for reason: LocalModelUnavailabilityReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence on-device models."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is disabled. Enable it in Settings to use on-device models."
        case .modelNotReady:
            return "The on-device model is not ready yet. Try again after download completes."
        case .frameworkNotAvailable:
            return "The Foundation Models framework is not available in this build environment."
        case .unknown:
            return "The on-device model is unavailable for an unknown reason."
        }
    }

    /// Throws ``MixlError/localModelUnavailable(reason:message:)`` when the on-device model is not available.
    ///
    /// Convenience wrapper around ``unavailabilityReason()`` for `try`-based control flow at the
    /// start of an inference pipeline.
    ///
    /// - Throws: ``MixlError/localModelUnavailable(reason:message:)`` when ``unavailabilityReason()``
    ///   returns non-`nil`.
    public static func requireAvailable() throws {
        if let reason = unavailabilityReason() {
            throw MixlError.localModelUnavailable(
                reason: reason,
                message: message(for: reason)
            )
        }
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
enum LocalModelAvailability {
    static func unavailabilityReason() -> LocalModelUnavailabilityReason? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
#endif
