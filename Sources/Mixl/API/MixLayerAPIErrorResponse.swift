import Foundation

/// An error object returned in the OpenAI-compatible MixLayer API error envelope.
public struct MixLayerAPIErrorResponse: Codable, Sendable, Equatable {
    /// A human-readable description of the error.
    public let message: String

    /// The error category (for example, `invalid_request_error`).
    public let type: String

    /// A machine-readable error code when provided by the API.
    public let code: String?

    /// Initializes an API error response.
    public init(message: String, type: String, code: String? = nil) {
        self.message = message
        self.type = type
        self.code = code
    }
}

struct MixLayerAPIErrorEnvelope: Decodable {
    let error: MixLayerAPIErrorResponse
}

enum MixLayerAPIErrorParser {
    static func parseAPIError(from data: Data) -> MixLayerAPIErrorResponse? {
        try? JSONDecoder().decode(MixLayerAPIErrorEnvelope.self, from: data).error
    }

    static func httpError(statusCode: Int, data: Data?) -> MixlError {
        let apiError = data.flatMap { parseAPIError(from: $0) }
        return .httpError(statusCode: statusCode, apiError: apiError)
    }
}
