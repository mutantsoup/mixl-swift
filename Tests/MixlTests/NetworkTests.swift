import XCTest
@testable import Mixl

final class NetworkTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
    }
    
    func testAPIServiceNormalCompletion() async throws {
        // Given
        let apiKey = "test-api-key"
        let baseURL = URL(string: "https://models.mixlayer.ai/v1")!
        
        let responseJson = """
        {
          "id": "chatcmpl-mock",
          "object": "chat.completion",
          "created": 1677652288,
          "model": "qwen/qwen3.5-27b",
          "choices": [{
            "index": 0,
            "message": {
              "role": "assistant",
              "content": "Mocked response content"
            },
            "finish_reason": "stop"
          }]
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://models.mixlayer.ai/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(apiKey)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            
            // Verify body contains expected fields
            var bodyData: Data? = request.httpBody
            if bodyData == nil, let bodyStream = request.httpBodyStream {
                bodyStream.open()
                defer { bodyStream.close() }
                let bufferSize = 1024
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                let len = bodyStream.read(&buffer, maxLength: bufferSize)
                if len > 0 {
                    bodyData = Data(bytes: buffer, count: len)
                }
            }
            
            if let data = bodyData {
                if let requestObj = try? JSONDecoder().decode(ChatCompletionRequest.self, from: data) {
                    XCTAssertEqual(requestObj.model, "qwen/qwen3.5-27b")
                    XCTAssertEqual(requestObj.messages.first?.content, "Hello")
                } else {
                    XCTFail("Failed to decode request body")
                }
            } else {
                XCTFail("Request body is empty")
            }
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = responseJson.data(using: .utf8)!
            return (response, data)
        }
        
        // Construct URLSession using MockURLProtocol
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)
        
        let apiService = APIService(apiKey: apiKey, baseURL: baseURL, session: mockSession)
        
        // When
        let request = ChatCompletionRequest(model: "qwen/qwen3.5-27b", messages: [.user("Hello")])
        let response = try await apiService.createChatCompletion(request: request)
        
        // Then
        XCTAssertEqual(response.id, "chatcmpl-mock")
        XCTAssertEqual(response.choices.first?.message.content, "Mocked response content")
    }
    
    func testAPIServiceStreamingCompletion() async throws {
        // Given
        let apiKey = "test-api-key"
        let baseURL = URL(string: "https://models.mixlayer.ai/v1")!
        
        let eventStreamData = """
        data: {"id":"1","object":"chunk","created":123,"model":"qwen","choices":[{"index":0,"delta":{"role":"assistant"}}]}
        
        data: {"id":"2","object":"chunk","created":123,"model":"qwen","choices":[{"index":0,"delta":{"content":"Hi"}}]}
        
        data: [DONE]
        
        """
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let data = eventStreamData.data(using: .utf8)!
            return (response, data)
        }
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)
        
        let apiService = APIService(apiKey: apiKey, baseURL: baseURL, session: mockSession)
        
        // When
        let request = ChatCompletionRequest(model: "qwen/qwen3.5-27b", messages: [.user("Hello")], stream: true)
        let stream = try await apiService.createChatCompletionStream(request: request)
        
        var chunks: [ChatCompletionChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        
        // Then
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].choices.first?.delta.role, .assistant)
        XCTAssertEqual(chunks[1].choices.first?.delta.content, "Hi")
    }
    
    func testAPIServiceHTTPErrorParsing() async throws {
        let apiKey = "test-api-key"
        let baseURL = URL(string: "https://models.mixlayer.ai/v1")!

        let errorJson = """
        {
          "error": {
            "message": "Model not found.",
            "type": "model_not_found",
            "code": "model_not_found"
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = errorJson.data(using: .utf8)!
            return (response, data)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)
        let apiService = APIService(apiKey: apiKey, baseURL: baseURL, session: mockSession)

        do {
            _ = try await apiService.createChatCompletion(
                request: ChatCompletionRequest(model: "missing/model", messages: [.user("Hello")])
            )
            XCTFail("Expected MixLayerError to be thrown")
        } catch let error as MixLayerError {
            XCTAssertEqual(
                error,
                .httpError(
                    statusCode: 404,
                    apiError: APIErrorResponse(
                        message: "Model not found.",
                        type: "model_not_found",
                        code: "model_not_found"
                    )
                )
            )
        }
    }

    func testChatCompletionRequestEncodesSupportedParameters() throws {
        let request = ChatCompletionRequest(
            model: "qwen/qwen3.5-27b",
            messages: [.user("Hello")],
            reasoningEffort: .medium,
            frequencyPenalty: 0.5,
            maxCompletionTokens: 128,
            stop: ["END"],
            seed: 42,
            responseFormat: .jsonObject()
        )

        let data = try JSONEncoder().encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"reasoning_effort\":\"medium\""))
        XCTAssertTrue(json.contains("\"frequency_penalty\":0.5"))
        XCTAssertTrue(json.contains("\"max_completion_tokens\":128"))
        XCTAssertTrue(json.contains("\"stop\":[\"END\"]"))
        XCTAssertTrue(json.contains("\"seed\":42"))
        XCTAssertTrue(json.contains("\"response_format\":{\"type\":\"json_object\"}"))
    }

    func testAPIServiceIntegrationTest() async throws {
        // Gated: Only run this integration test if real API key is set in environmental variables
        guard let apiKey = ProcessInfo.processInfo.environment["MIXLAYER_API_KEY"], !apiKey.isEmpty else {
            throw XCTSkip("MIXLAYER_API_KEY environment variable not set.")
        }
        
        let client = MixLayerClient(apiKey: apiKey)
        
        // 1. Test standard chat completions
        let response = try await client.chat.create(
            model: .qwen3_5_4b_free,
            messages: [.user("Say 'Hello' in exactly one word.")]
        )
        
        XCTAssertFalse(response.choices.isEmpty)
        let content = response.choices.first?.message.content ?? ""
        XCTAssertTrue(content.lowercased().contains("hello"))
        print("\n--- Standard Completion Response ---")
        print(content)
        print("------------------------------------\n")
        
        // 2. Test streaming completions
        let stream = try await client.chat.createStream(
            model: .qwen3_5_4b_free,
            messages: [.user("Count from 1 to 3.")],
            thinking: true
        )
        
        var receivedChunk = false
        for try await chunk in stream {
            receivedChunk = true
            if let delta = chunk.choices.first?.delta {
                print("Received chunk delta: \(delta.content ?? delta.reasoningContent ?? "")")
            }
        }
        XCTAssertTrue(receivedChunk)
    }
}

// MockURLProtocol class for intercepting URLSession requests
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("requestHandler not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}
