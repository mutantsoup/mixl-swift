# Mixl: Swift Client for MixLayer (iOS/macOS/watchOS/tvOS)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift: 5.9](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)

**Mixl** is a lightweight, fully async, type-safe Swift client library for accessing [MixLayer API](https://docs.mixlayer.com) inference services. It is designed specifically for Apple platforms, wrapping MixLayer's OpenAI-compatible API and custom capabilities (like extended Qwen thinking/reasoning modes) in modern Swift interfaces.

---

## 📖 Reference & Documentation

* **Agent & Developer Guidelines**: [AGENT.md](file:///Users/danmurrelljr/Dev/mutantsoup/mixl_ios/AGENT.md) — Architectural rules, coding styles, and implementation checklists.
* **MixLayer API Spec**: [MIXLAYER.md](file:///Users/danmurrelljr/Dev/mutantsoup/mixl_ios/MIXLAYER.md) — Comprehensive reference of REST endpoints, parameters, models, and sampling configuration.

---

## Features

- [x] **OpenAI-Compatible**: Drop-in API wrapper mapping to `models.mixlayer.ai`.
- [x] **Modern Swift Concurrency**: Native support for `async/await`.
- [x] **Extended Thinking/Reasoning Mode**: Direct access to model reasoning steps in `reasoningContent` fields.
- [x] **SSE Streaming**: Process reasoning and text tokens on-the-fly using Swift's `AsyncThrowingStream`.
- [x] **Tool / Function Calling**: Fully type-safe JSON Schema model declarations and responses.
- [x] **Zero External Dependencies**: Pure Swift code built on top of Apple's foundation frameworks (`URLSession`, `Codable`).

---

## Installation

### Swift Package Manager (SPM)

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/danmurrelljr/mixl_ios.git", from: "1.0.0")
]
```

Or add the package directly inside Xcode: **File -> Add Packages...** and paste the repository URL.

---

## Quick Start

### 1. Initialize the Client

```swift
import Mixl

let client = MixLayerClient(apiKey: "your-mixlayer-api-key")
```

### 2. Standard Chat Completion

```swift
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [
        .system("You are a helpful assistant."),
        .user("Why is the sky blue?")
    ]
)

if let content = response.choices.first?.message.content {
    print("Answer: \(content)")
}
```

### 3. Extended Reasoning (Thinking Mode)

Toggle thinking mode with the `thinking` flag to capture the model's chain-of-thought before its answer.

```swift
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [.user("What is 17 * 23? Explain step-by-step.")],
    thinking: true
)

if let reasoning = response.choices.first?.message.reasoningContent {
    print("Thinking Process:\n\(reasoning)")
}

if let content = response.choices.first?.message.content {
    print("Answer:\n\(content)")
}
```

### 4. Streaming Tokens (Including Reasoning)

Handle real-time tokens dynamically by iterating over the stream. Reasoning tokens stream first, followed by content.

```swift
let stream = try await client.chat.createStream(
    model: .qwen3_5_27b,
    messages: [.user("Write a poem about binary code.")],
    thinking: true
)

for try await chunk in stream {
    if let reasoningDelta = chunk.choices.first?.delta.reasoningContent {
        // Update thinking UI
        print("[Thinking]: \(reasoningDelta)", terminator: "")
    }
    if let contentDelta = chunk.choices.first?.delta.content {
        // Update answer UI
        print(contentDelta, terminator: "")
    }
}
```

---

## Contributing

Please review [AGENT.md](file:///Users/danmurrelljr/Dev/mutantsoup/mixl_ios/AGENT.md) for detailed guidelines on the project's code conventions, architecture pattern, and pull request checklist.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
