import Foundation
import Mixl

// MARK: - Orchestrator Examples

extension ExamplesApp {
    static func runOrchestratorExamplesMenu() async {
        guard let connection = resolveCloudConnection() else {
            print(missingCloudConnectionMessage())
            await waitForEnter()
            return
        }

        let client = makeOrchestratorClient(connection)
        var shouldReturn = false

        while !shouldReturn {
            print("""

            --- Unified Orchestrator (MixlClient) Examples ---
            \(connectionBanner(connection))

            1. Route Cloud model (\(exampleModel.rawValue)) -> Cloud Client
            2. Route Local model (apple/foundation) -> Local Client\(localOrchestratorAvailabilityNote())
            3. Direct cloud access (client.cloud) — bypass the router
            4. Direct local access (client.local) — bypass the router\(localOrchestratorAvailabilityNote())
            5. Custom Logic Router (checks prompt size locally vs cloud)
            6. Run All Orchestrator Examples
            7. Back to main menu
            8. Quit

            Enter selection (1-8):
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
                await runCustomLogicRouterExample(connection: connection)
                await waitForEnter()
            case "6":
                await runAllOrchestratorExamples(client: client)
                await waitForEnter()
            case "7":
                shouldReturn = true
            case "8":
                quit()
            default:
                print("\n⚠️ Invalid selection. Please enter a number between 1 and 8.")
                await waitForEnter()
            }
        }
    }

    static func runCustomLogicRouterExample(connection: CloudConnection) async {
        print("\n[Orchestrator Custom Logic] Routing based on prompt character length...")

        // Define a custom logic router that routes prompts under 100 characters to local, others to cloud
        let sizeRouter = MixlLogicRouter { request, context in
            let totalLength = request.messages.compactMap { $0.content?.count }.reduce(0, +)
            print("   [Router Logic] Prompt length is \(totalLength) characters.")
            if totalLength < 100 && context.isLocalAvailable {
                print("   [Router Logic] Length < 100 and local is available. Routing to LOCAL (.appleFoundation).")
                return .local(request.copy(withModel: Model.appleFoundation.rawValue))
            } else {
                let dest = context.isLocalAvailable ? "Length >= 100" : "Local model unavailable"
                print("   [Router Logic] \(dest). Routing to CLOUD (\(exampleModel.rawValue)).")
                return .cloud(request.copy(withModel: exampleModel.rawValue))
            }
        }

        let client = makeOrchestratorClient(connection, router: sizeRouter)

        let shortPrompt = "What is the capital of France?"
        let longPrompt = "Explain the difference between cloud computing and local on-device computing in detail, listing at least three pros and cons for each approach."

        print("\n--- Test 1: Short Prompt (\(shortPrompt.count) chars) ---")
        do {
            let start = Date()
            let response = try await client.chat.create(
                model: .routed,
                messages: [Message.user(shortPrompt)]
            )
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Routed Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }

        print("\n--- Test 2: Long Prompt (\(longPrompt.count) chars) ---")
        do {
            let start = Date()
            let response = try await client.chat.create(
                model: .routed,
                messages: [Message.user(longPrompt)]
            )
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Routed Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    static func localOrchestratorAvailabilityNote() -> String {
        guard isLocalExamplesRuntimeAvailable else {
            return "\n   (requires macOS 26+ / iOS 26+ with Foundation Models)"
        }
        if let reason = LocalModelSupport.unavailabilityReason() {
            return "\n   (device status: \(reason.rawValue))"
        }
        return ""
    }

    static func runOrchestratedCloudCompletion(client: MixlClient) async {
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

    static func runOrchestratedLocalCompletion(client: MixlClient) async {
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

    static func runDirectCloudCompletion(client: MixlClient) async {
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
    static func runDirectLocalCompletion(client: MixlClient) async {
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

    static func runAllOrchestratorExamples(client: MixlClient) async {
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

    static func runOrchestratedLocalIfAvailable(client: MixlClient) async {
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

    static func runDirectLocalIfAvailable(client: MixlClient) async {
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
}
