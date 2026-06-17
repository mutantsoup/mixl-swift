import Mixl
import MixlTesting
import XCTest

@testable import Mixl

final class ChatCompletionsTests: XCTestCase {
    func testChatCompletionSuccess() async throws {
        // Given
        let mockService = MockMixlService()
        let expectedResponse = ChatCompletionResponse(
            id: "chatcmpl-123",
            object: "chat.completion",
            created: 1677652288,
            model: "qwen/qwen3.5-27b",
            choices: [
                .init(
                    index: 0,
                    message: .init(role: .assistant, content: "Hello! How can I help you today?"),
                    finishReason: "stop"
                )
            ],
            usage: .init(promptTokens: 10, completionTokens: 8, totalTokens: 18)
        )
        await mockService.setStubbedResponse(expectedResponse)
        
        let client = MixLayerClient(apiKey: "key", service: mockService)
        
        // When
        let response = try await client.chat.create(
            model: .qwen3_5_27b,
            messages: [.user("Hi")],
            thinking: true,
            temperature: 0.7
        )
        
        // Then
        XCTAssertEqual(response.id, "chatcmpl-123")
        XCTAssertEqual(response.choices.first?.message.content, "Hello! How can I help you today?")
        
        // Verify mock recorded request
        let lastRequest = await mockService.lastRequest
        XCTAssertNotNil(lastRequest)
        XCTAssertEqual(lastRequest?.model, "qwen/qwen3.5-27b")
        XCTAssertEqual(lastRequest?.messages.first?.content, "Hi")
        XCTAssertEqual(lastRequest?.thinking, true)
        XCTAssertEqual(lastRequest?.temperature, 0.7)
    }
    
    func testChatCompletionFailure() async throws {
        // Given
        let mockService = MockMixlService()
        let expectedError = NSError(domain: "test", code: 456, userInfo: nil)
        await mockService.setStubbedError(expectedError)
        
        let client = MixLayerClient(apiKey: "key", service: mockService)
        
        // When/Then
        do {
            _ = try await client.chat.create(
                model: .qwen3_5_27b,
                messages: [.user("Hi")]
            )
            XCTFail("Expected error to be thrown")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "test")
            XCTAssertEqual(nsError.code, 456)
        }
    }
}
