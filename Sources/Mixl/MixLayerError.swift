import Foundation

/// Errors thrown by the Mixl client when communicating with the MixLayer API.
public enum MixLayerError: Error, Sendable, Equatable {
    /// The server returned a response that could not be interpreted as HTTP.
    case invalidResponse

    /// The server returned a non-success HTTP status code.
    case httpError(statusCode: Int, apiError: APIErrorResponse?)

    /// A request or response payload could not be encoded or decoded.
    case decodingFailed(String)

    /// A request payload could not be encoded.
    case encodingFailed(String)

    /// A transport-level failure occurred while sending the request.
    case network(String)
}

/// An error object returned in the OpenAI-compatible MixLayer error envelope.
public struct APIErrorResponse: Codable, Sendable, Equatable {
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

struct APIErrorEnvelope: Decodable {
    let error: APIErrorResponse
}

enum MixLayerErrorParser {
    static func parseAPIError(from data: Data) -> APIErrorResponse? {
        try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error
    }

    static func httpError(statusCode: Int, data: Data?) -> MixLayerError {
        let apiError = data.flatMap { parseAPIError(from: $0) }
        return .httpError(statusCode: statusCode, apiError: apiError)
    }
}
