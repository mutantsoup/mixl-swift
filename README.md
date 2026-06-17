# Mixl: Swift Client for MixLayer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift: 5.9](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)

**Mixl** is a lightweight, fully async, type-safe Swift client library for accessing [MixLayer API](https://docs.mixlayer.com) inference services. It targets Apple platforms (iOS, macOS, watchOS, tvOS, and visionOS), wrapping MixLayer's OpenAI-compatible API and custom capabilities (like extended Qwen thinking/reasoning modes) in modern Swift interfaces.

---

## Reference & Documentation

* **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md)
* **Changelog**: [CHANGELOG.md](CHANGELOG.md)
* **Agent & Developer Guidelines**: [AGENTS.md](AGENTS.md) — Architectural rules, coding styles, and implementation checklists.
* **MixLayer API Spec**: [MIXLAYER.md](MIXLAYER.md) — Comprehensive reference of REST endpoints, parameters, models, and sampling configuration.

---

## Features

- [x] **OpenAI-Compatible**: Drop-in API wrapper mapping to `models.mixlayer.ai`.
- [x] **Modern Swift Concurrency**: Native support for `async/await`.
- [x] **Extended Thinking/Reasoning Mode**: Direct access to model reasoning steps in `reasoningContent` fields.
- [x] **SSE Streaming**: Process reasoning and text tokens on-the-fly using Swift's `AsyncThrowingStream`.
- [x] **Tool / Function Calling**: Fully type-safe JSON Schema model declarations and responses.
- [x] **Typed Errors**: `MixlError` with MixLayer API error envelope parsing via `MixLayerAPIErrorResponse`.
- [x] **Zero External Dependencies**: Pure Swift code built on top of Apple's foundation frameworks (`URLSession`, `Codable`).
- [x] **On-Device Foundation Models** (macOS 26+ / iOS 26+): `LocalClient` with the same `chat.create` / `chat.createStream` API shape as `MixLayerClient`, backed by Apple's Foundation Models framework.

---

## Installation

### Swift Package Manager (SPM)

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/mutantsoup/mixl-swift.git", from: "0.1.0")
]
```

Or add the package directly inside Xcode: **File -> Add Packages...** and paste the repository URL.

For unit tests, also add the `MixlTesting` product to your test target:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: ["MyApp", "Mixl", "MixlTesting"]
)
```

API reference documentation is available via DocC in Xcode (**Product -> Build Documentation**) or by opening `Sources/Mixl/Mixl.docc`.

---

## Quick Start

### 1. Initialize the Client

```swift
import Mixl

let client = MixLayerClient(apiKey: "your-mixlayer-api-key")
```

### 2. Standard Chat Completion (Non-Thinking)

By default, omit `thinking` and `reasoningEffort` for instruct-style responses. This is the typical mode for concise chat, classification, and tool calling.

```swift
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [
        .system("You are a helpful assistant."),
        .user("Why is the sky blue?")
    ],
    temperature: 0.7
)

if let content = response.choices.first?.message.content {
    print("Answer: \(content)")
}

// Optional: some models may populate reasoningContent even without thinking
// parameters. Use thinking: false to force it off, or ignore reasoningContent in UI.
if let reasoning = response.choices.first?.message.reasoningContent {
    print("Reasoning (optional): \(reasoning)")
}
```

To explicitly disable thinking on models that might default to it:

```swift
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [.user("Answer in one sentence.")],
    thinking: false
)
```

### 3. Extended Reasoning with `thinking: true`

Pass `thinking: true` to enable MixLayer's chain-of-thought mode. The model returns internal reasoning in `reasoningContent` separately from the visible answer in `content`.

```swift
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [.user("What is 17 * 23? Explain step-by-step.")],
    thinking: true,
    temperature: 1.0
)

if let reasoning = response.choices.first?.message.reasoningContent {
    print("Thinking Process:\n\(reasoning)")
}

if let content = response.choices.first?.message.content {
    print("Answer:\n\(content)")
}
```

### 4. Extended Reasoning with `reasoningEffort`

MixLayer also accepts OpenAI's `reasoning_effort` parameter. Mixl maps it to the typed `ReasoningEffort` enum:

```swift
try await client.chat.create(..., reasoningEffort: .low)
try await client.chat.create(..., reasoningEffort: .medium)
try await client.chat.create(..., reasoningEffort: .high)
```

> **Note:** Per [MixLayer's reasoning docs](https://docs.mixlayer.com/reasoning), `reasoning_effort` is an OpenAI-compatible alias with effort levels reserved for future use — today it effectively enables thinking the same way as `thinking: true`. Prefer `thinking: true` for clarity unless you need OpenAI parameter parity. Streaming behavior may vary by model SKU.

Example using `reasoningEffort`:

```swift
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [.user("What is 17 * 23?")],
    reasoningEffort: .medium,
    temperature: 1.0
)
```

### 5. Streaming Tokens (Including Reasoning)

Handle real-time tokens dynamically by iterating over the stream. With thinking enabled, reasoning tokens typically arrive in `reasoningContent` before visible answer tokens in `content`.

```swift
let stream = try await client.chat.createStream(
    model: .qwen3_5_27b,
    messages: [.user("Write a poem about binary code.")],
    thinking: true,
    temperature: 1.0
)

for try await chunk in stream {
    if let reasoningDelta = chunk.choices.first?.delta.reasoningContent {
        print("[Thinking]: \(reasoningDelta)", terminator: "")
    }
    if let contentDelta = chunk.choices.first?.delta.content {
        print(contentDelta, terminator: "")
    }
}
```

The same streaming pattern works with `reasoningEffort` instead of `thinking: true`. Whether `reasoningContent` appears — and how it differs by effort level — can vary by model; test against your target SKU.

### 6. On-Device Inference with `LocalClient`

Use `LocalClient` for Apple Intelligence on-device models. It mirrors the cloud client's API shape but does not require a MixLayer API key. Use `Model.appleFoundation` and guard for OS and device availability:

```swift
import Mixl

if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
    if let reason = LocalModelSupport.unavailabilityReason() {
        print("On-device model unavailable: \(LocalModelSupport.message(for: reason))")
    } else {
        let client = LocalClient()
        let response = try await client.chat.create(
            model: .appleFoundation,
            messages: [
                .system("You are a helpful assistant."),
                .user("Summarize Swift concurrency in one sentence.")
            ],
            temperature: 0.7
        )
        print(response.choices.first?.message.content ?? "")
    }
}
```

Streaming works the same way as the cloud client:

```swift
let stream = try await client.chat.createStream(
    model: .appleFoundation,
    messages: [.user("Count from 1 to 5.")]
)

for try await chunk in stream {
    if let delta = chunk.choices.first?.delta.content {
        print(delta, terminator: "")
    }
}
```

**Supported on local path:** `temperature`, `maxCompletionTokens` / `maxTokens`.

**Stripped on local path (logged):** `thinking`, `reasoningEffort`, `top_p`, `top_k`, penalties, `stop`, and `seed` — removed so cloud-shaped requests work with a future orchestrator; Mixl logs each dropped parameter via `os.Logger`.

**Strict on local path (throws `MixlError.unsupportedParameter`):** `tools`, JSON `response_format`, and tool messages — these change response semantics and must not be silently ignored.

Wrong model identifiers still throw `MixlError.modelNotSupported`; unavailable devices throw `MixlError.localModelUnavailable`.

See [MIXLAYER.md](MIXLAYER.md#ml-ref-local) for the local backend compatibility table.

---

## Running the Examples

An interactive command-line app demonstrates MixLayer cloud completions (non-thinking, streaming reasoning, tool calling) and local on-device Foundation Models examples.

**Cloud examples** use **`Model.qwen3_5_4b_free`** and require a MixLayer API key:

```bash
export MIXLAYER_API_KEY="your-api-key"
swift run MixlExamples
```

**Local examples** use **`Model.appleFoundation`**, require **macOS 26+ / iOS 26+** with Apple Intelligence enabled, and do not need an API key. Select option **2** from the main menu.

Sign up for a free API key at the [MixLayer Console](https://console.mixlayer.com) if you do not have one. If the key is not set, cloud examples print setup instructions; local examples remain available when the device supports them.

### Running tests

```bash
swift test
```

| Backend | Unit / mock tests | Live integration test | Gate |
| --- | --- | --- | --- |
| MixLayer cloud | Always run | `testMixLayerAPIServiceIntegrationTest` | Set `MIXLAYER_API_KEY` |
| Local (Foundation Models) | Always run | `testLocalClientIntegrationTest` | Foundation Models SDK linked + on-device model available |

Without the gate conditions, integration tests are **skipped** (not failed). On CI runners without the Foundation Models SDK, the local integration test skips automatically.

---

## Contributing

Please review [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before opening a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
