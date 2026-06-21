import Foundation
import Mixl

// MARK: - Shared Support

extension ExamplesApp {
    static var isLocalExamplesRuntimeAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    static func waitForEnter() async {
        print("\nPress Enter to return to the menu...")
        _ = readLine()
    }

    /// Prints the farewell message and exits the app. Used by the `Quit` option in
    /// every menu so the user can exit without returning to the main menu first.
    static func quit() -> Never {
        print("\nGoodbye! 👋")
        exit(0)
    }

    // MARK: - Cloud connection

    /// How the cloud-backed examples should reach MixLayer.
    struct CloudConnection {
        /// The bearer credential sent as `apiKey` — a real MixLayer key in direct mode,
        /// or a user/session token in proxy mode.
        let token: String
        /// A custom base URL (the key proxy) when proxying, or `nil` for the MixLayer cloud.
        let baseURL: URL?
        /// Which environment variable (or fallback) supplied `token`, for display.
        let tokenSource: String
        var viaProxy: Bool { baseURL != nil }
    }

    /// Resolves the cloud connection from the environment, supporting two modes:
    ///
    /// - **Proxy:** if `MIXLAYER_BASE_URL` is set, route through it using a bearer token
    ///   (`MIXLAYER_AUTH_TOKEN`, falling back to `MIXLAYER_API_KEY`, then a dev placeholder).
    ///   No real API key is required on this side.
    /// - **Direct:** otherwise, connect straight to MixLayer using `MIXLAYER_API_KEY`.
    ///
    /// Returns `nil` if neither is configured.
    static func resolveCloudConnection() -> CloudConnection? {
        let env = ProcessInfo.processInfo.environment
        func nonEmpty(_ key: String) -> String? {
            guard let value = env[key], !value.isEmpty else { return nil }
            return value
        }

        if let baseURLString = nonEmpty("MIXLAYER_BASE_URL"), let baseURL = URL(string: baseURLString) {
            let token: String
            let source: String
            if let t = nonEmpty("MIXLAYER_AUTH_TOKEN") {
                token = t; source = "MIXLAYER_AUTH_TOKEN"
            } else if let k = nonEmpty("MIXLAYER_API_KEY") {
                token = k; source = "MIXLAYER_API_KEY (fallback)"
            } else {
                token = "examples-dev-token"; source = "built-in placeholder"
            }
            return CloudConnection(token: token, baseURL: baseURL, tokenSource: source)
        }
        if let key = nonEmpty("MIXLAYER_API_KEY") {
            return CloudConnection(token: key, baseURL: nil, tokenSource: "MIXLAYER_API_KEY")
        }
        return nil
    }

    /// Builds a cloud client for the resolved connection.
    static func makeCloudClient(_ connection: CloudConnection) -> MixLayerClient {
        if let baseURL = connection.baseURL {
            return MixLayerClient(apiKey: connection.token, baseURL: baseURL)
        }
        return MixLayerClient(apiKey: connection.token)
    }

    /// Builds an orchestrator client for the resolved connection, optionally with a custom router.
    static func makeOrchestratorClient(_ connection: CloudConnection, router: (any MixlRouter)? = nil) -> MixlClient {
        switch (connection.baseURL, router) {
        case let (baseURL?, router?): return MixlClient(apiKey: connection.token, baseURL: baseURL, router: router)
        case let (baseURL?, nil):     return MixlClient(apiKey: connection.token, baseURL: baseURL)
        case let (nil, router?):      return MixlClient(apiKey: connection.token, router: router)
        case (nil, nil):              return MixlClient(apiKey: connection.token)
        }
    }

    /// A banner that makes the active connection mode unmistakable, credential masked.
    static func connectionBanner(_ connection: CloudConnection) -> String {
        if let baseURL = connection.baseURL {
            return """
            🔌 PROXY MODE — not calling MixLayer directly; no API key used on this side.
               Routing through: \(baseURL.absoluteString)
               Auth token sent to proxy: \(maskedCredential(connection.token))  [source: \(connection.tokenSource)]
            """
        }
        return """
        🔑 DIRECT MODE — connecting to MixLayer cloud with your API key.
           API key: \(maskedCredential(connection.token))  [source: \(connection.tokenSource)]
        """
    }

    private static func maskedCredential(_ value: String) -> String {
        guard value.count > 8 else { return "****" }
        return "\(value.prefix(4))****************\(value.suffix(4))"
    }

    /// Setup instructions shown when no cloud connection is configured.
    static func missingCloudConnectionMessage() -> String {
        """
        ===================================================================
        ❌ No cloud connection configured.

        Run the cloud-backed examples one of two ways:

        1) Directly against MixLayer (requires an API key):
             export MIXLAYER_API_KEY="your_api_key_here"

        2) Through the local key proxy (no API key on this side):
             # in proxy/:  MIXLAYER_API_KEY="..." npm start
             export MIXLAYER_BASE_URL="http://localhost:8787/mixlayer/v1"
             # optional:  export MIXLAYER_AUTH_TOKEN="your-user-token"

        Then rerun:
             swift run MixlExamples
        ===================================================================
        """
    }
}
