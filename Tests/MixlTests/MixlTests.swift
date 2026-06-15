import XCTest
@testable import Mixl

final class MixlTests: XCTestCase {
    func testClientInitialization() {
        let apiKey = "test-api-key"
        let client = MixLayerClient(apiKey: apiKey)
        
        XCTAssertEqual(client.apiKey, apiKey)
        XCTAssertEqual(client.baseURL.absoluteString, "https://models.mixlayer.ai/v1")
    }
    
    func testModelSerialization() throws {
        // Test system message
        let systemMessage = Message.system("System prompt")
        XCTAssertEqual(systemMessage.role, .system)
        XCTAssertEqual(systemMessage.content, "System prompt")
        XCTAssertNil(systemMessage.reasoningContent)
        
        // Test user message
        let userMessage = Message.user("Hello")
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(userMessage.content, "Hello")
        
        // Test assistant message with reasoning
        let assistantMessage = Message(
            role: .assistant,
            content: "The answer is 42.",
            reasoningContent: "Let me think about it."
        )
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.content, "The answer is 42.")
        XCTAssertEqual(assistantMessage.reasoningContent, "Let me think about it.")
        
        // Encode and check json structure keys (snake_case conversion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(assistantMessage)
        
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"content\":\"The answer is 42.\""))
        XCTAssertTrue(jsonString!.contains("\"reasoning_content\":\"Let me think about it.\""))
        XCTAssertTrue(jsonString!.contains("\"role\":\"assistant\""))
        
        // Decode back
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(Message.self, from: data)
        XCTAssertEqual(decodedMessage.role, .assistant)
        XCTAssertEqual(decodedMessage.content, "The answer is 42.")
        XCTAssertEqual(decodedMessage.reasoningContent, "Let me think about it.")
    }
    
    func testCustomModelSerialization() throws {
        let customModel = Model.custom("my-custom-model/v2")
        XCTAssertEqual(customModel.rawValue, "my-custom-model/v2")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(customModel)
        
        let decoder = JSONDecoder()
        let decodedModel = try decoder.decode(Model.self, from: data)
        XCTAssertEqual(decodedModel, customModel)
        XCTAssertEqual(decodedModel.rawValue, "my-custom-model/v2")
    }
}
