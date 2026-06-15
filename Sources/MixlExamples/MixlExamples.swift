import Foundation
import Mixl

@main
struct ExamplesApp {
    /// Free-tier Qwen model — works with any MixLayer API key (no paid SKU required).
    private static let exampleModel = Model.qwen3_5_4b_free

    static func main() async {
        guard let apiKey = ProcessInfo.processInfo.environment["MIXLAYER_API_KEY"], !apiKey.isEmpty else {
            print("""
            ===================================================================
            ❌ Error: MIXLAYER_API_KEY environment variable is not set.
            
            To run the Mixl examples:
            1. Sign up for a free account at: https://console.mixlayer.com/sign-up
            2. Go to the dashboard and create a new API Key under:
               https://console.mixlayer.com/app/api-keys
            3. Export it in your terminal session before running this executable:
               export MIXLAYER_API_KEY="your_api_key_here"
            4. Rerun this examples app:
               swift run MixlExamples
            ===================================================================
            """)
            return
        }

        let client = MixLayerClient(apiKey: apiKey)
        var shouldQuit = false

        while !shouldQuit {
            print("""

            ==================================================
            🚀 Mixl (MixLayer Swift SDK) Examples CLI
            ==================================================
            Model: \(exampleModel.rawValue) (free tier)
            API Key detected: \(String(apiKey.prefix(4)))****************\(String(apiKey.suffix(4)))

            Please select an example to run:
            1. Standard Chat Completion (non-thinking / instruct mode)
            2. Streaming Reasoning (pick thinking mode…)
            3. Tool / Function Calling (non-thinking)
            4. Run All Examples
            5. Quit

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
                print("\n--- Running All Examples ---")
                await runStandardCompletion(client: client)
                print("\n----------------------------")
                for mode in ReasoningExampleMode.allCases {
                    await runStreamingReasoning(client: client, mode: mode)
                    print("\n----------------------------")
                }
                await runToolCalling(client: client)
                print("\n----------------------------")
                print("All examples completed!")
                await waitForEnter()
            case "5":
                print("\nGoodbye! 👋")
                shouldQuit = true
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 5.")
                await waitForEnter()
            }
        }
    }

    // MARK: - Examples

    private static func runStandardCompletion(client: MixLayerClient) async {
        print("\n[Example 1] Standard Chat Completion (non-thinking)...")
        print("No thinking or reasoningEffort parameters — instruct mode.")
        print("Sending request to model: \(exampleModel.rawValue)")

        do {
            let response = try await client.chat.create(
                model: exampleModel,
                messages: [
                    .system("You are a helpful assistant that answers concisely."),
                    .user("Explain what MixLayer is in one sentence.")
                ],
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

        do {
            let stream = try await client.chat.createStream(
                model: exampleModel,
                messages: [
                    .user("If I have 3 apples, eat 1, and buy 4 more, how many apples do I have? Solve it step-by-step.")
                ],
                thinking: mode.thinking,
                reasoningEffort: mode.reasoningEffort,
                temperature: 1.0
            )

            print("\n🤔 Thinking process:")
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

                print("\nSending tool output back to the model...")
                let followUpMessages = [
                    messages[0],
                    choice.message,
                    .tool(simulatedTime, toolCallId: toolCall.id)
                ]

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
