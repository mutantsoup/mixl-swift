import XCTest
@testable import Mixl

final class StreamingTests: XCTestCase {
    func testSSEStreamParserCompleteLines() throws {
        let parser = SSEStreamParser()
        
        let sampleSSE = """
        data: {"id":"1","object":"chat.completion.chunk","created":123,"model":"qwen","choices":[{"index":0,"delta":{"role":"assistant"}}]}
        
        data: {"id":"2","object":"chat.completion.chunk","created":123,"model":"qwen","choices":[{"index":0,"delta":{"reasoning_content":"Thinking..."}}]}
        
        data: {"id":"3","object":"chat.completion.chunk","created":123,"model":"qwen","choices":[{"index":0,"delta":{"content":"Hello"}}]}
        
        data: [DONE]
        """
        
        var chunks: [ChatCompletionChunk] = []
        var isDone = false
        
        let lines = sampleSSE.components(separatedBy: "\n")
        for line in lines {
            let parsed = try parser.parse(line: line + "\n")
            switch parsed {
            case .chunk(let chunk):
                chunks.append(chunk)
            case .done:
                isDone = true
            case .empty:
                break
            }
        }
        
        XCTAssertTrue(isDone)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].choices.first?.delta.role, .assistant)
        XCTAssertEqual(chunks[1].choices.first?.delta.reasoningContent, "Thinking...")
        XCTAssertEqual(chunks[2].choices.first?.delta.content, "Hello")
    }
    
    func testSSEStreamParserSplitLines() throws {
        let parser = SSEStreamParser()
        
        // Feed partial line
        let part1 = "data: {\"id\":\"1\",\"object\":\"chat.completion.chunk\",\"created\":123,\"model\":\"qwen\",\"choi"
        let part2 = "ces\":[{\"index\":0,\"delta\":{\"content\":\"Hi\"}}]}\n"
        
        let res1 = try parser.parse(line: part1)
        XCTAssertEqual(res1, .empty) // buffered, not complete
        
        let res2 = try parser.parse(line: part2)
        switch res2 {
        case .chunk(let chunk):
            XCTAssertEqual(chunk.choices.first?.delta.content, "Hi")
        default:
            XCTFail("Expected complete chunk after receiving end of line")
        }
    }
    
    func testMockClientStreamConsumption() async throws {
        // Define stubbed stream
        let expectedChunks = [
            ChatCompletionChunk(id: "1", object: "chunk", created: 123, model: "qwen", choices: [.init(index: 0, delta: .init(role: .assistant))]),
            ChatCompletionChunk(id: "2", object: "chunk", created: 123, model: "qwen", choices: [.init(index: 0, delta: .init(reasoningContent: "Thinking..."))]),
            ChatCompletionChunk(id: "3", object: "chunk", created: 123, model: "qwen", choices: [.init(index: 0, delta: .init(content: "Hello"))])
        ]
        
        let stream = AsyncThrowingStream<ChatCompletionChunk, Error> { continuation in
            for chunk in expectedChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        
        // Update mock implementation to return this stream
        // To do this, let's write a mock stream helper
        let streamingMock = StreamingMockService(stream: stream)
        let streamingClient = MixLayerClient(apiKey: "key", service: streamingMock)
        
        let chunkStream = try await streamingClient.chat.createStream(
            model: .qwen3_5_27b,
            messages: [.user("Test stream")]
        )
        
        var received: [ChatCompletionChunk] = []
        for try await chunk in chunkStream {
            received.append(chunk)
        }
        
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received[0].choices.first?.delta.role, .assistant)
        XCTAssertEqual(received[1].choices.first?.delta.reasoningContent, "Thinking...")
        XCTAssertEqual(received[2].choices.first?.delta.content, "Hello")
    }
}

// Simple streaming mock service
actor StreamingMockService: MixLayerService {
    private let stream: AsyncThrowingStream<ChatCompletionChunk, Error>
    
    init(stream: AsyncThrowingStream<ChatCompletionChunk, Error>) {
        self.stream = stream
    }
    
    func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        fatalError("Not used in stream test")
    }
    
    func createChatCompletionStream(request: ChatCompletionRequest) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        return stream
    }
}
