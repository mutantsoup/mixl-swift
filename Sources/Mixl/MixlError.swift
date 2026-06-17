import Foundation

/// Errors thrown by Mixl across cloud and local inference backends.
///
/// Use a single ``MixlError`` type when catching failures from either ``MixLayerClient`` or
/// ``LocalClient``. Cases are grouped by backend below; see <doc:LocalInference> for local
/// handling and parameter compatibility.
///
/// Cloud-only parsing helpers live in ``MixLayerAPIErrorResponse`` and `MixLayerAPIErrorParser` (internal).
/// Local-only unavailability reasons live in ``LocalModelUnavailabilityReason``.
public enum MixlError: Error, Sendable, Equatable {
    // MARK: Cloud (MixLayer API)

    /// The server returned a response that could not be interpreted as HTTP.
    case invalidResponse

    /// The MixLayer server returned a non-success HTTP status code.
    ///
    /// When the response body is JSON, ``MixLayerAPIErrorResponse`` is parsed into the associated value.
    case httpError(statusCode: Int, apiError: MixLayerAPIErrorResponse?)

    /// A transport-level failure occurred while sending a request to MixLayer.
    case network(String)

    // MARK: Shared

    /// A request or response payload could not be encoded or decoded.
    case decodingFailed(String)

    /// A request payload could not be encoded.
    case encodingFailed(String)

    /// The requested model identifier is not supported by this client or backend.
    ///
    /// Thrown when the model string does not match the active client—for example, passing a Qwen
    /// cloud identifier to ``LocalClient``, or ``Model/appleFoundation`` to ``MixLayerClient``.
    ///
    /// Compare with ``localModelUnavailable(reason:message:)``, which indicates the model is correct
    /// but the device or OS cannot run it.
    case modelNotSupported(model: String, backend: String)

    // MARK: Local (Foundation Models)

    /// The on-device Foundation Model is not available on this device or OS configuration.
    ///
    /// Inspect ``LocalModelUnavailabilityReason`` for the specific condition. Preflight with
    /// ``LocalModelSupport/unavailabilityReason()`` to avoid this error in UI flows.
    case localModelUnavailable(reason: LocalModelUnavailabilityReason, message: String?)

    /// A request parameter changes response semantics and is not supported on the local backend.
    ///
    /// Thrown for `tools`, JSON `response_format`, and tool messages in the conversation history.
    /// Cloud-only sampling and reasoning parameters are stripped with an `os.Logger` message instead
    /// (see `LocalRequestSanitizer`).
    case unsupportedParameter(String)

    /// On-device inference failed after the local model was available.
    ///
    /// Availability checks passed, but Foundation Models returned an error during `respond` or
    /// `streamResponse`. The associated string contains a localized error description.
    case localInferenceFailed(String)
}
