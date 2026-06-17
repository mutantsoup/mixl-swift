import Foundation

/// Cloud inference client for the MixLayer API.
///
/// Use ``MixLayerClient`` to configure API authentication and host base URLs,
/// and access inference through ``chat``.
public final class MixLayerClient: Sendable {
    /// The API key used to authenticate requests.
    public let apiKey: String

    /// The base server URL for the MixLayer API endpoints.
    public let baseURL: URL

    internal let service: any MixlService

    /// Entry point for Chat Completions endpoints.
    public var chat: MixlChatCompletionsService {
        MixlChatCompletionsService(service: service)
    }

    /// Initializes a new client instance for the MixLayer API.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for client authentication.
    ///   - baseURL: The base URL of the API. Defaults to `https://models.mixlayer.ai/v1`.
    ///   - session: The `URLSession` used for network requests.
    ///   - service: An optional ``MixlService`` implementation to inject for testing.
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://models.mixlayer.ai/v1")!,
        session: URLSession = .shared,
        service: (any MixlService)? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.service = service ?? MixLayerAPIService(apiKey: apiKey, baseURL: baseURL, session: session)
    }
}
