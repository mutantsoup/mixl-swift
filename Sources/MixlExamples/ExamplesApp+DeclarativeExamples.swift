import Foundation
import Mixl

// MARK: - Declarative API Examples

extension ExamplesApp {
    static func runDeclarativeExamplesMenu() async {
        guard let connection = resolveCloudConnection() else {
            print(missingCloudConnectionMessage())
            await waitForEnter()
            return
        }

        let client = makeOrchestratorClient(connection)
        var shouldReturn = false

        while !shouldReturn {
            print("""

            --- Declarative API Examples (client.run) ---
            \(connectionBanner(connection))

            1. Cloud completion — composed with @PromptBuilder + modifiers
            2. Local completion — same syntax, on-device\(localOrchestratorAvailabilityNote())
            3. Two-model chain — draft on one model, refine on another
            4. Run All Declarative Examples
            5. Back to main menu
            6. Quit

            Enter selection (1-6):
            """, terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            switch input {
            case "1":
                await runDeclarativeCloudCompletion(client: client)
                await waitForEnter()
            case "2":
                await runDeclarativeLocalIfAvailable(client: client, interactive: true)
                await waitForEnter()
            case "3":
                await runDeclarativeChain(client: client)
                await waitForEnter()
            case "4":
                await runAllDeclarativeExamples(client: client)
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

    // MARK: - Cloud

    static func runDeclarativeCloudCompletion(client: MixlClient) async {
        print("\n[Declarative 1] Cloud completion composed declaratively (\(exampleModel.rawValue))...")

        // Compose content with the @PromptBuilder (note the inline `if`), then configure it with
        // chainable modifiers — the SwiftUI-style sugar over the same orchestrator pipeline.
        let wantsConcise = true
        let prompt = Prompt {
            System("You are a helpful assistant.")
            if wantsConcise {
                System("Answer in a single sentence.")
            }
            User("Why is composing prompts declaratively useful?")
        }
        .temperature(0.5)
        .maxCompletionTokens(400)

        print("\n💬 Input Prompt:")
        for msg in prompt.resolvedMessages() {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }

        do {
            let start = Date()
            let response = try await client.run(exampleModel, prompt)
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Declarative Cloud Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    // MARK: - Local

    static func runDeclarativeLocalCompletion(client: MixlClient) async {
        print("\n[Declarative 2] Local completion composed declaratively (apple/foundation)...")
        print("Identical syntax to the cloud example — only the model changes. Routing sends it on-device.")

        // Foundation Models honors temperature and max tokens; reasoning/penalties/tools are not used here.
        let prompt = Prompt {
            System("You are a concise on-device assistant.")
            User("In one sentence, what is a benefit of on-device inference?")
        }
        .temperature(0.5)
        .maxCompletionTokens(400)

        print("\n💬 Input Prompt:")
        for msg in prompt.resolvedMessages() {
            print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
        }

        do {
            let start = Date()
            let response = try await client.run(.appleFoundation, prompt)
            let duration = Date().timeIntervalSince(start)
            print("\n✨ Declarative Local Response:")
            print(response.choices.first?.message.content ?? "")
            print(String(format: "\n⏱️ Time taken: %.3f seconds", duration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    // MARK: - Two-model chain

    static func runDeclarativeChain(client: MixlClient) async {
        print("\n[Declarative 3] Chaining two requests across two models (outline → paragraph)...")
        print("Chaining is just sequential `run` calls: one model drafts an outline, another rewrites it as prose.")

        // Draft on the on-device model when available (showing cloud + local together); otherwise draft
        // on the cloud model. The refine step always runs on the cloud model.
        let draftModel: Model
        if localAvailableForExamples() {
            draftModel = .appleFoundation
            print("   Draft model: apple/foundation (on-device)   Refine model: \(exampleModel.rawValue) (cloud)")
        } else {
            draftModel = exampleModel
            print("   Local unavailable — drafting and refining on \(exampleModel.rawValue) (cloud).")
            print("   (With Apple Intelligence enabled, the draft would run on-device for a true cross-backend chain.)")
        }

        let question = "How should a mobile app decide between on-device and cloud inference?"

        do {
            // Step 1 — a quick draft as a bulleted outline.
            let draftPrompt = Prompt {
                System("Outline the answer as 3–5 short bullet points, each starting with \"- \". Do not write any paragraphs, headings, or preamble.")
                User(question)
            }
            .temperature(0.7)

            print("\n💬 Draft Prompt (\(draftModel.rawValue)):")
            for msg in draftPrompt.resolvedMessages() {
                print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
            }

            let draftStart = Date()
            let draft = try await client.run(draftModel, draftPrompt)
            let draftDuration = Date().timeIntervalSince(draftStart)
            let draftText = draft.choices.first?.message.content ?? ""
            print("\n📝 Draft (outline):")
            print(draftText)
            print(String(format: "\n⏱️ Time taken: %.3f seconds", draftDuration))

            // Step 2 — refine on a different model, turning the outline into flowing prose.
            let refinePrompt = Prompt {
                System("You are an editor. Rewrite the outline below into 1-3 polished paragraphs. Return only the paragraphs — no bullet points, headings, or preamble.")
                User(question)
                Assistant(draftText)
                User("Rewrite the outline above in 1-3 paragraphs, suitable for middle schoolers.")
            }
            .temperature(0.3)

            print("\n💬 Refine Prompt (\(exampleModel.rawValue)):")
            for msg in refinePrompt.resolvedMessages() {
                print("  [\(msg.role.rawValue.uppercased())]: \(msg.content ?? "")")
            }

            let refineStart = Date()
            let refined = try await client.run(exampleModel, refinePrompt)
            let refineDuration = Date().timeIntervalSince(refineStart)
            print("\n✨ Refined (paragraph):")
            print(refined.choices.first?.message.content ?? "")
            print(String(format: "\n⏱️ Time taken: %.3f seconds", refineDuration))
        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    // MARK: - Run all

    static func runAllDeclarativeExamples(client: MixlClient) async {
        print("\n--- Running All Declarative Examples ---")

        await runDeclarativeCloudCompletion(client: client)
        print("\n----------------------------")

        await runDeclarativeLocalIfAvailable(client: client, interactive: false)
        print("\n----------------------------")

        await runDeclarativeChain(client: client)
        print("\n----------------------------")

        print("All declarative examples completed!")
    }

    // MARK: - Local availability helpers

    /// Whether the on-device model is linked, runnable, and currently available.
    static func localAvailableForExamples() -> Bool {
        guard isLocalExamplesRuntimeAvailable else { return false }
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            return LocalModelSupport.unavailabilityReason() == nil
        }
        return false
    }

    static func runDeclarativeLocalIfAvailable(client: MixlClient, interactive: Bool) async {
        guard isLocalExamplesRuntimeAvailable else {
            print("\n⏭️ Skipping declarative local example — requires iOS 26.0+ / macOS 26.0+.")
            return
        }
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            if let reason = LocalModelSupport.unavailabilityReason() {
                let detail = LocalModelSupport.message(for: reason)
                if interactive {
                    print("""
                    ===================================================================
                    ❌ On-device model unavailable: \(reason.rawValue)
                       \(detail)
                    ===================================================================
                    """)
                } else {
                    print("\n⏭️ Skipping declarative local example — on-device model unavailable: \(reason.rawValue)")
                }
            } else {
                await runDeclarativeLocalCompletion(client: client)
            }
        }
    }
}
