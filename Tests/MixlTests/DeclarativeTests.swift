import Mixl
import MixlTesting
import XCTest

@testable import Mixl

final class DeclarativeTests: XCTestCase {
    private var cloud: MockMixlService!
    private var local: MockMixlService!
    private var client: MixlClient!

    override func setUp() async throws {
        try await super.setUp()
        cloud = MockMixlService()
        local = MockMixlService()
        client = MixlClient(apiKey: "test-key", cloudService: cloud, localService: local)
        await stub(cloud)
        await stub(local)
    }

    private func stub(_ service: MockMixlService) async {
        await service.setStubbedResponse(
            ChatCompletionResponse(
                id: "resp",
                object: "chat.completion",
                created: 1,
                model: "m",
                choices: [.init(index: 0, message: .init(role: .assistant, content: "ok"), finishReason: "stop")],
                usage: .init(promptTokens: 1, completionTokens: 1, totalTokens: 2)
            )
        )
    }

    // MARK: - Composition

    func testComposesMessagesAndUsesBaseModel() async throws {
        _ = try await client.run(.qwen3_5_4b_free) {
            System("You are concise.")
            User("Hello")
        }

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.model, Model.qwen3_5_4b_free.rawValue)
        XCTAssertEqual(request?.messages, [.system("You are concise."), .user("Hello")])
    }

    func testRawMessagePassesThrough() async throws {
        let history: [Message] = [.user("earlier"), .assistant("reply")]
        _ = try await client.run(.qwen3_5_4b_free) {
            System("sys")
            for message in history { message }
            User("now")
        }

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.messages, [.system("sys"), .user("earlier"), .assistant("reply"), .user("now")])
    }

    func testModelModifierOverridesBaseModel() async throws {
        _ = try await client.run(.qwen3_5_4b_free, Prompt { User("hi") }.model(.qwen3_5_27b))

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.model, Model.qwen3_5_27b.rawValue)
    }

    // MARK: - Configuration modifiers

    func testSamplingAndReasoningModifiersMap() async throws {
        _ = try await client.run(
            .qwen3_5_4b_free,
            Prompt { User("x") }
                .temperature(0.5)
                .topP(0.9)
                .reasoning(.high)
                .thinking()
                .maxCompletionTokens(800)
                .seed(7)
                .stop("STOP")
        )

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.temperature, 0.5)
        XCTAssertEqual(request?.topP, 0.9)
        XCTAssertEqual(request?.reasoningEffort, .high)
        XCTAssertEqual(request?.thinking, true)
        XCTAssertEqual(request?.maxCompletionTokens, 800)
        XCTAssertEqual(request?.seed, 7)
        XCTAssertEqual(request?.stop, ["STOP"])
    }

    func testInnermostModifierWins() async throws {
        // `.temperature(0.2)` is closer to the content, so it wins over the outer `.temperature(0.8)`.
        _ = try await client.run(.qwen3_5_4b_free, Prompt { User("x") }.temperature(0.2).temperature(0.8))

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.temperature, 0.2)
    }

    func testResponseFormatModifier() async throws {
        _ = try await client.run(.qwen3_5_4b_free, Prompt { User("x") }.responseFormat(.jsonObject()))

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.responseFormat?.type, .jsonObject)
    }

    // MARK: - Tools DSL

    func testToolsDSLBuildsSchema() async throws {
        _ = try await client.run(.qwen3_5_4b_free, Prompt { User("time?") }.tools {
            FunctionTool("get_time", "Current time for a city") {
                Field("city", .string, "City name", required: true)
            }
        })

        let request = await cloud.lastRequest
        let tool = try XCTUnwrap(request?.tools?.first)
        XCTAssertEqual(tool.function.name, "get_time")
        XCTAssertEqual(tool.function.description, "Current time for a city")
        XCTAssertEqual(tool.function.parameters?.type, .object)
        XCTAssertEqual(tool.function.parameters?.properties?["city"]?.type, .string)
        XCTAssertEqual(tool.function.parameters?.required, ["city"])
    }

    // MARK: - PromptComponent

    private struct SupportPrompt: PromptComponent {
        var question: String
        var history: [Message]
        var includeDisclaimer: Bool

        var body: some PromptContent {
            System("You are a support agent.")
            for message in history { message }
            if includeDisclaimer {
                System("Add a brief disclaimer.")
            }
            User(question)
        }
    }

    func testPromptComponentComposesConditionalsAndLoops() async throws {
        _ = try await client.run(
            .qwen3_5_4b_free,
            SupportPrompt(question: "Help?", history: [.user("prior")], includeDisclaimer: true)
        )

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.messages, [
            .system("You are a support agent."),
            .user("prior"),
            .system("Add a brief disclaimer."),
            .user("Help?")
        ])
    }

    func testPromptComponentOmitsConditionalBranch() async throws {
        _ = try await client.run(
            .qwen3_5_4b_free,
            SupportPrompt(question: "Help?", history: [], includeDisclaimer: false)
        )

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.messages, [.system("You are a support agent."), .user("Help?")])
    }

    // MARK: - Transform & router modifiers (bridge to Phases 4–5)

    func testPerPromptTransformRewritesBeforeBackend() async throws {
        _ = try await client.run(
            .qwen3_5_4b_free,
            Prompt { User("Summarize Project Cerberus") }
                .mapContent { $0.replacingOccurrences(of: "Project Cerberus", with: "[REDACTED]") }
        )

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.messages.first?.content, "Summarize [REDACTED]")
    }

    func testClientTransformsRunBeforePromptTransforms() async throws {
        let clientWithTransform = MixlClient(
            apiKey: "test-key",
            transforms: [MixlTransform.mapContent { $0 + "-A" }],
            cloudService: cloud,
            localService: local
        )

        _ = try await clientWithTransform.run(
            .qwen3_5_4b_free,
            Prompt { User("x") }.mapContent { $0 + "-B" }
        )

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.messages.first?.content, "x-A-B")
    }

    func testPerPromptRouterOverrideRoutesToLocal() async throws {
        let toLocal = MixlLogicRouter { request, _ in .local(request) }

        _ = try await client.run(.qwen3_5_4b_free, Prompt { User("x") }.router(toLocal))

        let localRequest = await local.lastRequest
        let cloudRequest = await cloud.lastRequest
        XCTAssertNotNil(localRequest)
        XCTAssertNil(cloudRequest)
    }

    // MARK: - Custom modifier

    private struct Redacting: PromptModifier {
        let term: String
        func body(content: AnyPromptContent) -> some PromptContent {
            content.mapContent { $0.replacingOccurrences(of: term, with: "[REDACTED]") }
        }
    }

    func testCustomModifier() async throws {
        _ = try await client.run(
            .qwen3_5_4b_free,
            Prompt { User("the secret plan") }.modifier(Redacting(term: "secret"))
        )

        let request = await cloud.lastRequest
        XCTAssertEqual(request?.messages.first?.content, "the [REDACTED] plan")
    }

    // MARK: - Inspection

    func testResolvedMessagesAndToolsPreviewContent() {
        let prompt = Prompt {
            System("sys")
            User("hi")
        }
        .tools {
            FunctionTool("get_time", "Current time") {
                Field("city", .string, required: true)
            }
        }

        XCTAssertEqual(prompt.resolvedMessages(), [.system("sys"), .user("hi")])
        XCTAssertEqual(prompt.resolvedTools().first?.function.name, "get_time")
    }

    // MARK: - Streaming

    func testStreamingDeclarative() async throws {
        await cloud.setStubbedStreamChunks([
            ChatCompletionChunk(
                id: "c1",
                object: "chat.completion.chunk",
                created: 1,
                model: "m",
                choices: [.init(index: 0, delta: .init(role: .assistant, content: "hi"), finishReason: nil)]
            )
        ])

        let stream = try await client.stream(.qwen3_5_4b_free) {
            User("stream please")
        }

        var chunks: [ChatCompletionChunk] = []
        for try await chunk in stream { chunks.append(chunk) }

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks.first?.choices.first?.delta.content, "hi")
        let request = await cloud.lastRequest
        XCTAssertEqual(request?.stream, true)
        XCTAssertEqual(request?.messages, [.user("stream please")])
    }
}
