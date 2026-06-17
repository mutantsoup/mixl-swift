import Foundation
import Mixl

@main
struct ExamplesApp {
    /// Free-tier Qwen model — works with any MixLayer API key (no paid SKU required).
    private static let exampleModel = Model.qwen3_5_4b_free

    static func main() async {
        var shouldQuit = false

        while !shouldQuit {
            print("""

            ==================================================
            🚀 Mixl (MixLayer Swift SDK) Examples CLI
            ==================================================

            Please select a backend:
            1. MixLayer Cloud Examples (requires MIXLAYER_API_KEY)
            2. Local Foundation Models Examples (on-device, no API key)\(localExamplesAvailabilityNote())
            3. Unified Orchestrator Examples (MixlClient - routes automatically)
            4. Quit

            Enter selection (1-4):
            """, terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            switch input {
            case "1":
                await runCloudExamplesMenu()
            case "2":
                await runLocalExamplesMenu()
            case "3":
                await runOrchestratorExamplesMenu()
            case "4":
                print("\nGoodbye! 👋")
                shouldQuit = true
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 4.")
                await waitForEnter()
            }
        }
    }

    private static func localExamplesAvailabilityNote() -> String {
        guard isLocalExamplesRuntimeAvailable else {
            return "\n   (requires macOS 26+ / iOS 26+ with Foundation Models)"
        }
        if let reason = LocalModelSupport.unavailabilityReason() {
            return "\n   (device status: \(reason.rawValue))"
        }
        return ""
    }

    private static var isLocalExamplesRuntimeAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    // MARK: - Cloud Examples Menu

    private static func runCloudExamplesMenu() async {
        guard let apiKey = ProcessInfo.processInfo.environment["MIXLAYER_API_KEY"], !apiKey.isEmpty else {
            print("""
            ===================================================================
            ❌ Error: MIXLAYER_API_KEY environment variable is not set.

            To run the MixLayer cloud examples:
            1. Sign up for a free account at: https://console.mixlayer.com/sign-up
            2. Go to the dashboard and create a new API Key under:
               https://console.mixlayer.com/app/api-keys
            3. Export it in your terminal session before running this executable:
               export MIXLAYER_API_KEY="your_api_key_here"
            4. Rerun this examples app:
               swift run MixlExamples
            ===================================================================
            """)
            await waitForEnter()
            return
        }

        let client = MixLayerClient(apiKey: apiKey)
        var shouldReturn = false

        while !shouldReturn {
            print("""

            --- MixLayer Cloud Examples ---
            Model: \(exampleModel.rawValue) (free tier)
            API Key detected: \(String(apiKey.prefix(4)))****************\(String(apiKey.suffix(4)))

            1. Standard Chat Completion (non-thinking / instruct mode)
            2. Streaming Reasoning (pick thinking mode…)
            3. Tool / Function Calling (non-thinking)
            4. Run All Cloud Examples
            5. Back to main menu

            Enter selection (1-5):
            """, terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            switch input {
            case "1":
                await runStandardCompletion(client: client)
                await waitForEnter()
            case "2":
                if let mode = await promptReasoningMode() {
                    await runStreamingReasoning(client: client, mode: mode)
                    await waitForEnter()
                }
            case "3":
                await runToolCalling(client: client)
                await waitForEnter()
            case "4":
                print("\n--- Running All Cloud Examples ---")
                await runStandardCompletion(client: client)
                print("\n----------------------------")
                for mode in ReasoningExampleMode.allCases {
                    await runStreamingReasoning(client: client, mode: mode)
                    print("\n----------------------------")
                }
                await runToolCalling(client: client)
                print("\n----------------------------")
                print("All cloud examples completed!")
                await waitForEnter()
            case "5":
                shouldReturn = true
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 5.")
                await waitForEnter()
            }
        }
    }

    // MARK: - Local Examples Menu

    private static func runLocalExamplesMenu() async {
        guard isLocalExamplesRuntimeAvailable else {
            print("""
            ===================================================================
            ❌ Local examples require macOS 26+ / iOS 26+ with the Foundation
               Models framework. Build and run on an Apple Intelligence-capable
               device with Xcode 26 or later.
            ===================================================================
            """)
            await waitForEnter()
            return
        }

        if let reason = LocalModelSupport.unavailabilityReason() {
            print("""
            ===================================================================
            ❌ On-device model unavailable: \(reason.rawValue)
               \(LocalModelSupport.message(for: reason))
            ===================================================================
            """)
            await waitForEnter()
            return
        }

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            await runLocalExamplesMenuOnSupportedRuntime()
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
    private static func runLocalExamplesMenuOnSupportedRuntime() async {
        let client = LocalClient()
        let localModel = Model.appleFoundation
        var shouldReturn = false

        while !shouldReturn {
            print("""

            --- Local Foundation Models Examples ---
            Model: \(localModel.rawValue) (on-device, no API key)

            1. Standard Chat Completion
            2. Streaming Completion
            3. Run All Local Examples
            4. Back to main menu

            Enter selection (1-4):
            """, terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            switch input {
            case "1":
                await runLocalStandardCompletion(client: client, model: localModel)
                await waitForEnter()
            case "2":
                await runLocalStreamingCompletion(client: client, model: localModel)
                await waitForEnter()
            case "3":
                print("\n--- Running All Local Examples ---")
                await runLocalStandardCompletion(client: client, model: localModel)
                print("\n----------------------------")
                await runLocalStreamingCompletion(client: client, model: localModel)
                print("\n----------------------------")
                print("All local examples completed!")
                await waitForEnter()
            case "4":
                shouldReturn = true
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 4.")
                await waitForEnter()
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
    private static func runLocalStandardCompletion(client: LocalClient, model: Model) async {
        print("\n[Local Example 1] Standard Chat Completion (on-device)...")
        print("Sending request to model: \(model.rawValue)")

        let messages: [Message] = [
            .system("You are a helpful assistant that answers concisely."),
            .user("Explain what Swift concurrency is in one sentence.")
        ]

        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }

        do {
            let start = Date()
            let response = try await client.chat.create(
                model: model,
                messages: messages,
                temperature: 0.7
            )
            let duration = Date().timeIntervalSince(start)

            if let content = response.choices.first?.message.content {
                print("\n✨ Model Response:")
                print(content)
            } else {
                print("\n⚠️ No content returned.")
            }
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error running local chat completion: \(error)")
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
    private static func runLocalStreamingCompletion(client: LocalClient, model: Model) async {
        print("\n[Local Example 2] Streaming Completion (on-device)...")
        print("Sending streaming request to model: \(model.rawValue)")

        let messages: [Message] = [
            .user("Count from 1 to 5, one number per line.")
        ]

        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }

        do {
            let start = Date()
            let stream = try await client.chat.createStream(
                model: model,
                messages: messages,
                temperature: 0.7
            )

            print("\n✨ Streaming Response:")
            for try await chunk in stream {
                if let content = chunk.choices.first?.delta.content {
                    print(content, terminator: "")
                    fflush(stdout)
                }
            }
            print()
            let duration = Date().timeIntervalSince(start)
            print(String(format: "\n⏱️ Time taken: %.3f seconds (total streaming time)", duration))
        } catch {
            print("\n❌ Error running local stream: \(error)")
        }
    }

    // MARK: - Orchestrator Examples

    private static func runOrchestratorExamplesMenu() async {
        guard let apiKey = ProcessInfo.processInfo.environment["MIXLAYER_API_KEY"], !apiKey.isEmpty else {
            print("""
            ===================================================================
            ❌ Error: MIXLAYER_API_KEY environment variable is not set.

            The unified orchestrator requires MIXLAYER_API_KEY to instantiate
            the cloud routing client. Please set it in your environment:
               export MIXLAYER_API_KEY="your_api_key_here"
            ===================================================================
            """)
            await waitForEnter()
            return
        }

        let client = MixlClient(apiKey: apiKey)
        var shouldReturn = false

        while !shouldReturn {
            print("""

            --- Unified Orchestrator (MixlClient) Examples ---
            API Key detected: \(String(apiKey.prefix(4)))****************\(String(apiKey.suffix(4)))

            1. Route Cloud model (\(exampleModel.rawValue)) -> Cloud Client
            2. Route Local model (apple/foundation) -> Local Client\(localOrchestratorAvailabilityNote())
            3. Direct cloud access (client.cloud) — bypass the router
            4. Direct local access (client.local) — bypass the router\(localOrchestratorAvailabilityNote())
            5. Run All Orchestrator Examples
            6. Back to main menu

            Enter selection (1-6):
            """, terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            switch input {
            case "1":
                await runOrchestratedCloudCompletion(client: client)
                await waitForEnter()
            case "2":
                if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
                    if let reason = LocalModelSupport.unavailabilityReason() {
                        print("""
                        ===================================================================
                        ❌ On-device model unavailable: \(reason.rawValue)
                           \(LocalModelSupport.message(for: reason))
                        ===================================================================
                        """)
                    } else {
                        await runOrchestratedLocalCompletion(client: client)
                    }
                } else {
                    print("\n❌ Local model requires iOS 26.0+ / macOS 26.0+.")
                }
                await waitForEnter()
            case "3":
                await runDirectCloudCompletion(client: client)
                await waitForEnter()
            case "4":
                if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
                    if let reason = LocalModelSupport.unavailabilityReason() {
                        print("""
                        ===================================================================
                        ❌ On-device model unavailable: \(reason.rawValue)
                           \(LocalModelSupport.message(for: reason))
                        ===================================================================
                        """)
                    } else {
                        await runDirectLocalCompletion(client: client)
                    }
                } else {
                    print("\n❌ Local model requires iOS 26.0+ / macOS 26.0+.")
                }
                await waitForEnter()
            case "5":
                await runAllOrchestratorExamples(client: client)
                await waitForEnter()
            case "6":
                shouldReturn = true
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 6.")
                await waitForEnter()
            }
        }
    }

    private static func localOrchestratorAvailabilityNote() -> String {
        guard isLocalExamplesRuntimeAvailable else {
            return "\n   (requires macOS 26+ / iOS 26+ with Foundation Models)"
        }
        if let reason = LocalModelSupport.unavailabilityReason() {
            return "\n   (device status: \(reason.rawValue))"
        }
        return ""
    }

    private static func runOrchestratedCloudCompletion(client: MixlClient) async {
        print("\n[Orchestrator Example 1] Routing Cloud model (\(exampleModel.rawValue))...")
        let messages: [Message] = [
            .system("You are a helpful assistant that answers concisely."),
            .user("Explain in one sentence why routing between cloud and local is useful.")
        ]
        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }
        do {
            let start = Date()
            let response = try await client.chat.create(
                model: exampleModel,
                messages: messages
            )
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Routed Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    private static func runOrchestratedLocalCompletion(client: MixlClient) async {
        print("\n[Orchestrator Example 2] Routing Local model (apple/foundation)...")
        let messages: [Message] = [
            .system("You are a helpful assistant that answers concisely."),
            .user("Explain in one sentence why on-device processing is secure.")
        ]
        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }
        do {
            let start = Date()
            let response = try await client.chat.create(
                model: .appleFoundation,
                messages: messages
            )
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Routed Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    private static func runDirectCloudCompletion(client: MixlClient) async {
        print("\n[Orchestrator Example 3] Direct cloud access via client.cloud (router bypassed)...")
        print("Reaching the MixLayer cloud client directly, guaranteeing cloud execution.")
        let messages: [Message] = [
            .system("You are a helpful assistant that answers concisely."),
            .user("In one sentence, when would you bypass the router and call the cloud directly?")
        ]
        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }
        do {
            let start = Date()
            let response = try await client.cloud.chat.create(
                model: exampleModel,
                messages: messages
            )
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Direct Cloud Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
    private static func runDirectLocalCompletion(client: MixlClient) async {
        print("\n[Orchestrator Example 4] Direct local access via client.local (router bypassed)...")
        print("Reaching the on-device client directly, guaranteeing local execution.")
        let messages: [Message] = [
            .system("You are a helpful assistant that answers concisely."),
            .user("In one sentence, when would you bypass the router and run on-device directly?")
        ]
        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }
        do {
            let start = Date()
            let response = try await client.local.chat.create(
                model: .appleFoundation,
                messages: messages
            )
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Direct Local Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    private static func runAllOrchestratorExamples(client: MixlClient) async {
        print("\n--- Running All Orchestrator Examples ---")

        await runOrchestratedCloudCompletion(client: client)
        print("\n----------------------------")

        await runOrchestratedLocalIfAvailable(client: client)
        print("\n----------------------------")

        await runDirectCloudCompletion(client: client)
        print("\n----------------------------")

        await runDirectLocalIfAvailable(client: client)
        print("\n----------------------------")

        print("All orchestrator examples completed!")
    }

    private static func runOrchestratedLocalIfAvailable(client: MixlClient) async {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            if let reason = LocalModelSupport.unavailabilityReason() {
                print("\n⏭️ Skipping routed local example — on-device model unavailable: \(reason.rawValue)")
            } else {
                await runOrchestratedLocalCompletion(client: client)
            }
        } else {
            print("\n⏭️ Skipping routed local example — requires iOS 26.0+ / macOS 26.0+.")
        }
    }

    private static func runDirectLocalIfAvailable(client: MixlClient) async {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            if let reason = LocalModelSupport.unavailabilityReason() {
                print("\n⏭️ Skipping direct local example — on-device model unavailable: \(reason.rawValue)")
            } else {
                await runDirectLocalCompletion(client: client)
            }
        } else {
            print("\n⏭️ Skipping direct local example — requires iOS 26.0+ / macOS 26.0+.")
        }
    }

    // MARK: - Cloud Examples

    private static func runStandardCompletion(client: MixLayerClient) async {
        print("\n[Example 1] Standard Chat Completion (non-thinking)...")
        print("No thinking or reasoningEffort parameters — instruct mode.")
        print("Sending request to model: \(exampleModel.rawValue)")

        let messages: [Message] = [
            .system("You are a helpful assistant that answers concisely."),
            .user("Explain what MixLayer is in one sentence.")
        ]

        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }

        do {
            let start = Date()
            let response = try await client.chat.create(
                model: exampleModel,
                messages: messages,
                temperature: 0.7
            )
            let duration = Date().timeIntervalSince(start)

            let message = response.choices.first?.message
            if let content = message?.content {
                print("\n✨ Model Response:")
                print(content)
            } else {
                print("\n⚠️ No content returned.")
            }
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))

            if let reasoning = message?.reasoningContent, !reasoning.isEmpty {
                print("\nℹ️ reasoningContent was also returned (\(reasoning.count) chars).")
                print("   This can happen on some models/tiers even without thinking parameters.")
                print("   Use thinking: false to force it off, or ignore it in instruct-mode UI.")
            }
        } catch {
            print("\n❌ Error running Chat Completion: \(error)")
        }
    }

    private static func runStreamingReasoning(client: MixLayerClient, mode: ReasoningExampleMode) async {
        print("\n[Example 2] Streaming Reasoning — \(mode.displayName)")
        print(mode.documentationNote)
        print("Sending request to model: \(exampleModel.rawValue)")

        let messages: [Message] = [
            .user("If I have 3 apples, eat 1, and buy 4 more, how many apples do I have? Solve it step-by-step.")
        ]

        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }

        do {
            let start = Date()
            let stream = try await client.chat.createStream(
                model: exampleModel,
                messages: messages,
                thinking: mode.thinking,
                reasoningEffort: mode.reasoningEffort,
                temperature: 1.0
            )

            print("\n🧠 Reasoning Stream:")
            var startedContent = false
            var receivedReasoning = false

            for try await chunk in stream {
                if let delta = chunk.choices.first?.delta {
                    if let reasoning = delta.reasoningContent, !reasoning.isEmpty {
                        receivedReasoning = true
                        print(reasoning, terminator: "")
                        fflush(stdout)
                    }
                    if let content = delta.content {
                        if !startedContent {
                            print("\n\n✨ Final Answer:")
                            startedContent = true
                        }
                        print(content, terminator: "")
                        fflush(stdout)
                    }
                }
            }
            print()
            let duration = Date().timeIntervalSince(start)
            print(String(format: "\n⏱️ Time taken: %.3f seconds (total streaming time)", duration))

            if !receivedReasoning {
                print("\nℹ️ No reasoningContent deltas received in this stream.")
                print("   That can be normal for some model/tier + reasoningEffort combinations.")
                print("   Re-test with thinking: true or a larger model SKU if you need reasoning UI.")
            }
        } catch {
            print("\n❌ Error running Stream: \(error)")
        }
    }

    private static func runToolCalling(client: MixLayerClient) async {
        print("\n[Example 3] Tool / Function Calling (non-thinking)...")

        struct TimezoneArgs: Codable {
            let city: String
        }

        let timeTool = Tool(
            function: FunctionDefinition(
                name: "get_current_time",
                description: "Get the current local time for a specific city.",
                parameters: JSONSchema(
                    type: .object,
                    properties: [
                        "city": JSONSchema(type: .string, description: "The city name, e.g. London, Tokyo, New York")
                    ],
                    required: ["city"]
                ),
                strict: true
            )
        )

        let messages = [
            Message.user("What time is it in Tokyo right now?")
        ]

        print("No thinking parameters — tool calling uses default instruct mode.")
        print("Sending request with tool registered to model: \(exampleModel.rawValue)")

        print("\n💬 Input Prompt:")
        for msg in messages {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }

        do {
            let start1 = Date()
            let response = try await client.chat.create(
                model: exampleModel,
                messages: messages,
                tools: [timeTool]
            )
            let duration1 = Date().timeIntervalSince(start1)

            guard let choice = response.choices.first else {
                print("❌ No choices returned from model")
                return
            }

            if let toolCall = choice.message.toolCalls?.first {
                print("\n🔧 Model Requested Tool Execution:")
                print("   Tool Name: \(toolCall.function.name)")
                print("   Arguments: \(toolCall.function.arguments)")
                print(String(format: "\n⏱️ Initial request time (tool call request): %.3f seconds", duration1))

                let decodedArgs = try toolCall.function.decodeArguments(as: TimezoneArgs.self)
                print("   Decoded City: \(decodedArgs.city)")

                print("\n   [Running Local Tool...] Get current time in \(decodedArgs.city)")
                let simulatedTime = "9:30 PM (Tokyo Standard Time)"
                print("   Tool Output: \(simulatedTime)")

                let followUpMessages = [
                    messages[0],
                    choice.message,
                    .tool(simulatedTime, toolCallId: toolCall.id)
                ]

                print("\n💬 Sending tool output and conversation history back to the model:")
                for msg in followUpMessages {
                    if msg.role == .assistant, let toolCalls = msg.toolCalls {
                        print("  [ASSISTANT]: (Requested tool call: \(toolCalls.first?.function.name ?? ""))")
                    } else {
                        print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
                    }
                }

                let start2 = Date()
                let finalResponse = try await client.chat.create(
                    model: exampleModel,
                    messages: followUpMessages
                )
                let duration2 = Date().timeIntervalSince(start2)

                if let content = finalResponse.choices.first?.message.content {
                    print("\n✨ Model Response (Conditional on Tool Output):")
                    print(content)
                }
                print(String(format: "\n⏱️ Second request time (after tool execution): %.3f seconds", duration2))
            } else if let content = choice.message.content {
                print("\n✨ Model Response (No Tool Call Needed):")
                print(content)
                print(String(format: "\n⏱️ Request time: %.3f seconds", duration1))
            }
        } catch {
            print("\n❌ Error running Tool Calling: \(error)")
        }
    }

    // MARK: - Reasoning Mode Menu

    private enum ReasoningExampleMode: CaseIterable {
        case thinkingTrue
        case effortLow
        case effortMedium
        case effortHigh

        var displayName: String {
            switch self {
            case .thinkingTrue:
                return "thinking: true"
            case .effortLow:
                return "reasoningEffort: .low"
            case .effortMedium:
                return "reasoningEffort: .medium"
            case .effortHigh:
                return "reasoningEffort: .high"
            }
        }

        var documentationNote: String {
            switch self {
            case .thinkingTrue:
                return "Native MixLayer toggle. Prefer this when you want explicit reasoning mode."
            case .effortLow:
                return "OpenAI-compatible alias (low). Per MixLayer docs, levels are reserved for future use."
            case .effortMedium, .effortHigh:
                return "OpenAI-compatible alias. Per MixLayer docs, levels are reserved for future use."
            }
        }

        var thinking: Bool? {
            switch self {
            case .thinkingTrue:
                return true
            case .effortLow, .effortMedium, .effortHigh:
                return nil
            }
        }

        var reasoningEffort: ReasoningEffort? {
            switch self {
            case .thinkingTrue:
                return nil
            case .effortLow:
                return .low
            case .effortMedium:
                return .medium
            case .effortHigh:
                return .high
            }
        }
    }

    private static func promptReasoningMode() async -> ReasoningExampleMode? {
        print("""

        --- Streaming Reasoning Mode ---
        MixLayer accepts thinking: true or reasoningEffort (low/medium/high).
        Per MixLayer docs, effort levels are reserved for future use — behavior may vary by model/tier.

        1. thinking: true
        2. reasoningEffort: .low
        3. reasoningEffort: .medium
        4. reasoningEffort: .high
        5. Back to main menu

        Enter selection (1-5):
        """, terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        switch input {
        case "1": return .thinkingTrue
        case "2": return .effortLow
        case "3": return .effortMedium
        case "4": return .effortHigh
        case "5": return nil
        default:
            print("\n⚠️ Invalid selection.")
            return nil
        }
    }

    // MARK: - Helpers

    private static func waitForEnter() async {
        print("\nPress Enter to return to the menu...")
        _ = readLine()
    }
}
