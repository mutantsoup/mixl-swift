import Foundation
import Mixl

// MARK: - Local Examples Menu

extension ExamplesApp {
    static func runLocalExamplesMenu() async {
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
    static func runLocalExamplesMenuOnSupportedRuntime() async {
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
            5. Quit

            Enter selection (1-5):
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
            case "5":
                quit()
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 5.")
                await waitForEnter()
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)
    static func runLocalStandardCompletion(client: LocalClient, model: Model) async {
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
    static func runLocalStreamingCompletion(client: LocalClient, model: Model) async {
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
}
