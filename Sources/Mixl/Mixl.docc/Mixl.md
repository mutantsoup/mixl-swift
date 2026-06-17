# ``Mixl``

A type-safe Swift client for the [MixLayer API](https://docs.mixlayer.com) and Apple on-device Foundation Models.

## Overview

Mixl wraps MixLayer's OpenAI-compatible chat completions endpoint with native Swift concurrency, extended reasoning support, SSE streaming, and tool calling. Mixl also provides ``LocalClient`` for on-device inference via Apple's Foundation Models framework using the same ``MixlChatCompletionsService`` API shape.

### Cloud inference

Use ``MixLayerClient`` with a MixLayer API key and Qwen model identifiers (``Model/qwen3_5_4b_free``, etc.).

### Local inference

Use ``LocalClient`` with ``Model/appleFoundation`` on iOS 26+, macOS 26+, and other platforms where Foundation Models is available. See <doc:LocalInference> for availability checks, parameter compatibility, and error handling.

### Thinking modes (cloud only)

- **Non-thinking (default):** omit `thinking` and `reasoningEffort` for instruct-style responses.
- **`thinking: true`:** native MixLayer toggle; chain-of-thought in ``Message/reasoningContent`` when the model supports it.
- **`reasoningEffort`:** OpenAI-compatible alias (``ReasoningEffort/low``, ``ReasoningEffort/medium``, ``ReasoningEffort/high``). Per MixLayer docs, levels are reserved for future use; verify streaming behavior on your model SKU.

```swift
import Mixl

let client = MixLayerClient(apiKey: "your-api-key")

let response = try await client.chat.create(
    model: .qwen3_5_4b_free,
    messages: [.user("Hello!")]
)
```

For unit tests, add the `MixlTesting` product and inject `MockMixlService` through ``MixLayerClient/init(apiKey:baseURL:session:service:)`` or ``LocalClient/init(service:)``.

## Topics

### Essentials

- ``MixLayerClient``
- ``LocalClient``
- ``MixlChatCompletionsService``
- ``MixlService``
- ``MixlError``

### Local Inference

- <doc:LocalInference>
- ``LocalModelSupport``
- ``LocalModelUnavailabilityReason``
- ``Model/appleFoundation``
- ``MixlModelProvider``

### Messages and Models

- ``Model``
- ``Message``
- ``Role``
- ``ReasoningEffort``

### Requests and Responses

- ``ChatCompletionRequest``
- ``ChatCompletionResponse``
- ``ChatCompletionChunk``
- ``ChoiceDelta``

### Tool Calling

- ``Tool``
- ``FunctionDefinition``
- ``FunctionCall``
- ``ToolCall``
- ``JSONSchema``
- ``ResponseFormat``
