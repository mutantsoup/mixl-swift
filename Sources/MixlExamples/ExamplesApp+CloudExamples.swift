import Foundation
import Mixl

// MARK: - Cloud Examples Menu

extension ExamplesApp {
    static func runCloudExamplesMenu() async {
        guard let connection = resolveCloudConnection() else {
            print(missingCloudConnectionMessage())
            await waitForEnter()
            return
        }

        let client = makeCloudClient(connection)
        var shouldReturn = false

        while !shouldReturn {
            print("""

            --- MixLayer Cloud Examples ---
            Model: \(exampleModel.rawValue) (free tier)
            \(connectionBanner(connection))

            1. Standard Chat Completion (non-thinking / instruct mode)
            2. Streaming Reasoning (pick thinking mode…)
            3. Tool / Function Calling (non-thinking)
            4. Run All Cloud Examples
            5. Back to main menu
            6. Quit

            Enter selection (1-6):
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
            case "6":
                quit()
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 6.")
                await waitForEnter()
            }
        }
    }

    // MARK: - Cloud Examples

    static func runStandardCompletion(client: MixLayerClient) async {
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

    static func runStreamingReasoning(client: MixLayerClient, mode: ReasoningExampleMode) async {
        print("\n[Example 2] Streaming Reasoning — \(mode.displayName)")
        print(mode.documentationNote)
        print("Sending request to model: \(exampleModel.rawValue)")

        // With reasoning enabled, the reasoning stream *is* the step-by-step working, so we ask only
        // for the answer — telling the final response to also "solve step-by-step" muddies the
        // model's notion of what belongs in reasoning vs. content.
        let messages: [Message] = [
            .user("If I start with 3 apples, eat 1, then buy 4 more, how many apples do I have?")
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
                // A moderate temperature suits a deterministic task and curbs the rambling/looping
                // that high randomness can trigger; maxCompletionTokens is a hard cost ceiling so a
                // runaway reasoning loop can't generate unbounded (expensive) output.
                temperature: 0.5,
                maxCompletionTokens: 800
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

    static func runToolCalling(client: MixLayerClient) async {
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

    enum ReasoningExampleMode: CaseIterable {
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

    static func promptReasoningMode() async -> ReasoningExampleMode? {
        print("""

        --- Streaming Reasoning Mode ---
        MixLayer accepts thinking: true or reasoningEffort (low/medium/high).
        Per MixLayer docs, effort levels are reserved for future use — behavior may vary by model/tier.

        1. thinking: true
        2. reasoningEffort: .low
        3. reasoningEffort: .medium
        4. reasoningEffort: .high
        5. Back to the cloud menu
        6. Quit

        Enter selection (1-6):
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
        case "6": quit()
        default:
            print("\n⚠️ Invalid selection.")
            return nil
        }
    }
}
