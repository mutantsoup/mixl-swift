# ``Mixl``

A type-safe Swift client for the [MixLayer API](https://docs.mixlayer.com).

## Overview

Mixl wraps MixLayer's OpenAI-compatible chat completions endpoint with native Swift concurrency, extended reasoning support, SSE streaming, and tool calling.

### Thinking modes

- **Non-thinking (default):** omit `thinking` and `reasoningEffort` for instruct-style responses.
- **`thinking: true`:** native MixLayer toggle; chain-of-thought in ``Message/reasoningContent`` when the model supports it.
- **`reasoningEffort`:** OpenAI-compatible alias (``.low``, ``.medium``, ``.high``). Per MixLayer docs, levels are reserved for future use; verify streaming behavior on your model SKU.

```swift
import Mixl

let client = MixLayerClient(apiKey: "your-api-key")

let response = try await client.chat.create(
    model: .qwen3_5_4b_free,
    messages: [.user("Hello!")]
)
```

For unit tests, add the ``MixlTesting`` product and inject ``MockMixLayerService`` through ``MixLayerClient/init(apiKey:baseURL:session:service:)``.

## Topics

### Essentials

- ``MixLayerClient``
- ``ChatCompletionsService``
- ``MixLayerService``
- ``MixLayerError``

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
