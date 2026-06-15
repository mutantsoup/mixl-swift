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
- [x] **Typed Errors**: `MixLayerError` with OpenAI-style API error envelope parsing.
- [x] **Zero External Dependencies**: Pure Swift code built on top of Apple's foundation frameworks (`URLSession`, `Codable`).

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

---

## Running the Examples

An interactive command-line app demonstrates non-thinking completions, streaming reasoning (`thinking: true` and each `reasoningEffort` level), and tool calling. All examples use **`Model.qwen3_5_4b_free`** (`qwen/qwen3.5-4b-free`) so they run on a free MixLayer account without a paid model SKU.

```bash
export MIXLAYER_API_KEY="your-api-key"
swift run MixlExamples
```

Sign up for a free API key at the [MixLayer Console](https://console.mixlayer.com) if you do not have one. If the key is not set, the app prints setup instructions.

---

## Contributing

Please review [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before opening a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
