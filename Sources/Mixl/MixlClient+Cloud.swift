import Foundation

extension MixlClient {
    /// Direct access to the MixLayer cloud inference client.
    ///
    /// Exposes cloud-only parameters and endpoints. Use `cloud` if you want to bypass the router
    /// and guarantee execution in the cloud.
    public var cloud: MixLayerClient {
        MixLayerClient(
            apiKey: apiKey,
            baseURL: baseURL,
            service: cloudService
        )
    }
}
