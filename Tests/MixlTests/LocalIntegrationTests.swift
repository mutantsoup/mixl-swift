import XCTest
@testable import Mixl

final class LocalIntegrationTests: XCTestCase {
    /// Gated integration test: runs against Apple Foundation Models when the SDK is linked
    /// and ``LocalModelSupport/unavailabilityReason()`` is `nil`. Skips otherwise (same pattern
    /// as ``NetworkTests/testMixLayerAPIServiceIntegrationTest()`` with `MIXLAYER_API_KEY`).
    func testLocalClientIntegrationTest() async throws {
        try LocalIntegrationTestSupport.requireAvailableForLiveTesting()

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            try await runLiveLocalClientIntegration()
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
    private func runLiveLocalClientIntegration() async throws {
        let client = LocalClient()

        let response = try await client.chat.create(
            model: .appleFoundation,
            messages: [.user("Say 'Hello' in exactly one word.")]
        )

        XCTAssertFalse(response.choices.isEmpty)
        let content = response.choices.first?.message.content ?? ""
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.lowercased().contains("hello"))

        let stream = try await client.chat.createStream(
            model: .appleFoundation,
            messages: [.user("Count from 1 to 3.")]
        )

        var receivedContent = false
        for try await chunk in stream {
            if let delta = chunk.choices.first?.delta.content, !delta.isEmpty {
                receivedContent = true
            }
        }
        XCTAssertTrue(receivedContent)
    }
}

private enum LocalIntegrationTestSupport {
    static func requireAvailableForLiveTesting() throws {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) else {
            throw XCTSkip("Foundation Models requires iOS 26 / macOS 26 or later.")
        }
        guard LocalModelSupport.isFrameworkAvailable else {
            throw XCTSkip("Foundation Models framework not linked in this build environment.")
        }
        if let reason = LocalModelSupport.unavailabilityReason() {
            throw XCTSkip("\(reason.rawValue): \(LocalModelSupport.message(for: reason))")
        }
        #else
        throw XCTSkip("Foundation Models framework not linked in this build environment.")
        #endif
    }
}
