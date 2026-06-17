import Foundation

@available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
extension MixlClient {
    /// Direct access to the on-device local inference client.
    ///
    /// Exposes local-only configurations. Use `local` if you want to bypass the router
    /// and guarantee on-device execution.
    public var local: LocalClient {
        LocalClient(service: localService)
    }
}
