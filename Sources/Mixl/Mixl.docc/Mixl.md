# ``Mixl``

A type-safe Swift client for the [MixLayer API](https://docs.mixlayer.com) and Apple on-device Foundation Models.

## Overview

Mixl wraps MixLayer's OpenAI-compatible chat completions endpoint with native Swift concurrency, extended reasoning support, SSE streaming, and tool calling. Mixl also provides ``LocalClient`` for on-device inference via Apple's Foundation Models framework using the same ``MixlChatCompletionsService`` API shape.

### Cloud inference

Use ``MixLayerClient`` with a MixLayer API key and Qwen model identifiers (``Model/qwen3_5_4b_free``, etc.).

### Local inference

Use ``LocalClient`` with ``Model/appleFoundation`` on iOS 26+, macOS 26+, and other platforms where Foundation Models is available. See <doc:LocalInference> for availability checks, parameter compatibility, and error handling.

### Routing

Use ``MixlClient`` to route a single `chat.create` / `chat.createStream` call to the cloud or on-device backend automatically. Supply a ``MixlRouter`` policy — ``MixlDefaultRouter`` (model-based), ``MixlLogicRouter`` (inline closure), ``MixlFallbackRouter`` (cloud fallback when local is down), or ``MixlPatternRouter`` (PII/regex gating) — or implement your own. See <doc:Routing>.

### Transforming requests

Rewrite the request payload before it is routed — clean up a voice-transcribed prompt, redact sensitive terms, or inject a shared preamble — with a chain of ``MixlRequestTransform`` values on ``MixlClient``. Use ``MixlTransform`` for inline closures and ``MixlTransform/mapContent(_:)`` for the common case of editing message text. See <doc:Transforms>.

### Composing prompts declaratively

Build requests with a SwiftUI-style declarative API on ``MixlClient`` — composed content (``System``/``User``/``Assistant``), chainable modifiers (`.temperature`, `.reasoning`, `.tools`, …), reusable ``PromptComponent`` types, and custom ``PromptModifier`` types — all layered over the existing pipeline as pure sugar. Run with ``MixlClient/run(_:_:)`` / ``MixlClient/stream(_:_:)``. See <doc:Declarative>.

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

### Routing

- <doc:Routing>
- ``MixlClient``
- ``MixlRouter``
- ``MixlRoutingContext``
- ``MixlRoutingDecision``
- ``MixlDefaultRouter``
- ``MixlLogicRouter``
- ``MixlFallbackRouter``
- ``MixlPatternRouter``
- ``MixlPatternRule``
- ``Model/routed``

### Transforming requests

- <doc:Transforms>
- ``MixlRequestTransform``
- ``MixlTransform``

### Composing prompts declaratively

- <doc:Declarative>
- ``PromptContent``
- ``Prompt``
- ``PromptComponent``
- ``PromptModifier``
- ``PromptBuilder``

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
