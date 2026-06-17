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
            3. Quit

            Enter selection (1-3):
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
                print("\nGoodbye! 👋")
                shouldQuit = true
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 3.")
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
            let response = try await client.chat.create(
                model: model,
                messages: messages,
                temperature: 0.7
            )

            if let content = response.choices.first?.message.content {
                print("\n✨ Model Response:")
                print(content)
            } else {
                print("\n⚠️ No content returned.")
            }
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
        } catch {
            print("\n❌ Error running local stream: \(error)")
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
            let response = try await client.chat.create(
                model: exampleModel,
                messages: messages,
                temperature: 0.7
            )

            let message = response.choices.first?.message
            if let content = message?.content {
                print("\n✨ Model Response:")
                print(content)
            } else {
                print("\n⚠️ No content returned.")
            }

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
            let response = try await client.chat.create(
                model: exampleModel,
                messages: messages,
                tools: [timeTool]
            )

            guard let choice = response.choices.first else {
                print("❌ No choices returned from model")
                return
            }

            if let toolCall = choice.message.toolCalls?.first {
                print("\n🔧 Model Requested Tool Execution:")
                print("   Tool Name: \(toolCall.function.name)")
                print("   Arguments: \(toolCall.function.arguments)")

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

                let finalResponse = try await client.chat.create(
                    model: exampleModel,
                    messages: followUpMessages
                )

                if let content = finalResponse.choices.first?.message.content {
                    print("\n✨ Model Response (Conditional on Tool Output):")
                    print(content)
                }
            } else if let content = choice.message.content {
                print("\n✨ Model Response (No Tool Call Needed):")
                print(content)
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
