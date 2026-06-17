import XCTest
@testable import Mixl

final class LocalModelTests: XCTestCase {
    func testAppleFoundationModelProvider() {
        XCTAssertTrue(Model.appleFoundation.isAppleFoundation)
        XCTAssertEqual(Model.appleFoundation.provider, .appleFoundation)
        XCTAssertEqual(Model.appleFoundation.rawValue, "apple/foundation")
    }

    func testMixLayerModelsUseCloudProvider() {
        XCTAssertEqual(Model.qwen3_5_4b_free.provider, .mixLayerCloud)
        XCTAssertFalse(Model.qwen3_5_4b_free.isAppleFoundation)
    }

    func testPromptBuilderCombinesSystemAndConversation() throws {
        let built = try LocalPromptBuilder.build(from: [
            .system("You are helpful."),
            .user("Hello"),
            .assistant("Hi there."),
            .user("What is Mixl?")
        ])

        XCTAssertEqual(built.instructions, "You are helpful.")
        XCTAssertEqual(built.prompt, "User: Hello\nAssistant: Hi there.\nUser: What is Mixl?")
    }

    func testPromptBuilderRejectsToolMessages() {
        XCTAssertThrowsError(try LocalPromptBuilder.build(from: [
            .user("Run tool"),
            .tool("result", toolCallId: "call_1")
        ])) { error in
            XCTAssertEqual(error as? LocalPromptBuilder.Error, .unsupportedToolMessages)
        }
    }

    func testPromptBuilderRequiresUserMessage() {
        XCTAssertThrowsError(try LocalPromptBuilder.build(from: [
            .system("Only system")
        ])) { error in
            XCTAssertEqual(error as? LocalPromptBuilder.Error, .missingUserMessage)
        }
    }

    func testLocalModelSupportMessageForFrameworkNotAvailable() {
        let message = LocalModelSupport.message(for: .frameworkNotAvailable)
        XCTAssertTrue(message.contains("Foundation Models"))
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
    func testLocalClientRejectsCloudModel() async {
        let client = LocalClient(service: LocalInferenceService())

        do {
            _ = try await client.chat.create(
                model: .qwen3_5_4b_free,
                messages: [.user("Hello")]
            )
            XCTFail("Expected modelNotSupported error")
        } catch let error as MixlError {
            XCTAssertEqual(error, .modelNotSupported(model: Model.qwen3_5_4b_free.rawValue, backend: "Apple Foundation Models"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    #endif

    func testLocalRequestSanitizerStripsThinkingParameter() throws {
        let request = ChatCompletionRequest(
            model: Model.appleFoundation.rawValue,
            messages: [.user("Hello")],
            thinking: true,
            topP: 0.9
        )

        let prepared = try LocalRequestSanitizer.prepare(request)

        XCTAssertNil(prepared.thinking)
        XCTAssertNil(prepared.topP)
        XCTAssertEqual(prepared.messages, request.messages)
    }

    func testLocalRequestSanitizerStripsThinkingFalseSilently() throws {
        let request = ChatCompletionRequest(
            model: Model.appleFoundation.rawValue,
            messages: [.user("Hello")],
            thinking: false
        )

        let prepared = try LocalRequestSanitizer.prepare(request)

        XCTAssertNil(prepared.thinking)
    }

    func testLocalRequestSanitizerThrowsForTools() {
        let request = ChatCompletionRequest(
            model: Model.appleFoundation.rawValue,
            messages: [.user("Hello")],
            tools: [
                Tool(function: FunctionDefinition(name: "get_weather"))
            ]
        )

        XCTAssertThrowsError(try LocalRequestSanitizer.prepare(request)) { error in
            XCTAssertEqual(error as? MixlError, .unsupportedParameter("tools"))
        }
    }

    func testLocalRequestSanitizerThrowsForJSONResponseFormat() {
        let request = ChatCompletionRequest(
            model: Model.appleFoundation.rawValue,
            messages: [.user("Hello")],
            responseFormat: .jsonObject()
        )

        XCTAssertThrowsError(try LocalRequestSanitizer.prepare(request)) { error in
            XCTAssertEqual(error as? MixlError, .unsupportedParameter("response_format"))
        }
    }

    func testLocalRequestSanitizerThrowsForToolMessages() {
        let request = ChatCompletionRequest(
            model: Model.appleFoundation.rawValue,
            messages: [
                .user("Run tool"),
                .tool("result", toolCallId: "call_1")
            ]
        )

        XCTAssertThrowsError(try LocalRequestSanitizer.prepare(request)) { error in
            XCTAssertEqual(error as? MixlError, .unsupportedParameter("tool messages"))
        }
    }

    func testLocalRequestSanitizerThrowsForCloudModel() {
        let request = ChatCompletionRequest(
            model: Model.qwen3_5_4b_free.rawValue,
            messages: [.user("Hello")]
        )

        XCTAssertThrowsError(try LocalRequestSanitizer.prepare(request)) { error in
            XCTAssertEqual(
                error as? MixlError,
                .modelNotSupported(model: Model.qwen3_5_4b_free.rawValue, backend: "Apple Foundation Models")
            )
        }
    }
}

#if !canImport(FoundationModels)
extension LocalModelTests {
    func testLocalModelSupportReportsFrameworkUnavailableWithoutSDK() {
        XCTAssertFalse(LocalModelSupport.isFrameworkAvailable)
        XCTAssertEqual(LocalModelSupport.unavailabilityReason(), .frameworkNotAvailable)
    }
}
#endif
