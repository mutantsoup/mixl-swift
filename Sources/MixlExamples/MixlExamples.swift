import Foundation
import Mixl

@main
struct ExamplesApp {
    /// Free-tier Qwen model — works with any MixLayer API key (no paid SKU required).
    static let exampleModel = Model.qwen3_5_4b_free

    static func main() async {
        while true {
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
                quit()
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
}
