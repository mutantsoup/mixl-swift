# Local Inference

Run chat completions on-device with Apple Foundation Models through ``LocalClient``.

## Overview

Mixl supports two inference backends that share the same request and response types:

| Backend | Client | Model identifiers | Authentication |
| --- | --- | --- | --- |
| MixLayer cloud | ``MixLayerClient`` | `qwen/...` (``Model/qwen3_5_4b_free``, etc.) | MixLayer API key |
| Apple on-device | ``LocalClient`` | `apple/foundation` (``Model/appleFoundation``) | None |

Both clients expose the same ``MixlChatCompletionsService`` surface (`chat.create` and `chat.createStream`). A future orchestrator will route by ``Model/provider`` using ``MixlService``.

``LocalClient`` is marked `@available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *)` and requires the **Foundation Models** framework (Xcode 26 SDK). Builds without the framework compile successfully but throw ``MixlError/localModelUnavailable(reason:message:)`` with ``LocalModelUnavailabilityReason/frameworkNotAvailable``.

## Checking availability

Call ``LocalModelSupport/unavailabilityReason()`` before presenting on-device inference UI. Returns `nil` when inference should succeed, or a ``LocalModelUnavailabilityReason`` when it cannot.

```swift
import Mixl

if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
    if let reason = LocalModelSupport.unavailabilityReason() {
        let message = LocalModelSupport.message(for: reason)
        // Show settings prompt or fallback UI
    } else {
        let client = LocalClient()
        // ...
    }
}
```

Alternatively, call ``LocalModelSupport/requireAvailable()`` inside a `do/catch` block to throw ``MixlError/localModelUnavailable(reason:message:)``.

## Standard completion

```swift
if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
    try LocalModelSupport.requireAvailable()

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
```

## Streaming

Streaming uses Apple’s `streamResponse` API internally. Mixl maps aggregated snapshots to OpenAI-style ``ChatCompletionChunk`` deltas so the same consumption pattern works for cloud and local backends.

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

## Parameter compatibility

The local backend uses two policies so orchestrators can pass cloud-shaped requests to ``LocalClient``:

1. **Strip + log** — sampling and reasoning parameters Foundation Models does not expose are removed and logged at `info` via `os.Logger` (subsystem `com.mutantsoup.Mixl`, category `LocalInference`).
2. **Strict** — parameters that change response semantics throw ``MixlError/unsupportedParameter(_:)`` before inference starts.

### Supported

| Parameter | Notes |
| --- | --- |
| `messages` | System, user, and assistant roles only. Tool messages are rejected (strict). |
| `temperature` | Passed to Foundation Models `GenerationOptions`. |
| `maxCompletionTokens` / `maxTokens` | Maps to `maximumResponseTokens`. |
| `stream` | Use `chat.createStream` on ``LocalClient`` or ``MixLayerClient``. |

### Stripped (logged)

| Parameter | Notes |
| --- | --- |
| `thinking`, `reasoningEffort` | No on-device reasoning channel; stripped so shared call sites work. |
| `top_p`, `top_k`, penalties, `stop`, `seed` | Not exposed by Foundation Models `GenerationOptions` in Mixl. |

### Strict (throws)

| Parameter | Reason |
| --- | --- |
| `tools`, tool messages | Tool calling is not implemented for the local backend. |
| `responseFormat` (JSON) | Text completions only; JSON contracts would be silently violated. |

Passing a MixLayer cloud model (e.g. ``Model/qwen3_5_4b_free``) to ``LocalClient`` throws ``MixlError/modelNotSupported(model:backend:)``.

## Error semantics

Mixl distinguishes **unsupported** configuration from **unavailable** hardware or OS state:

| Error | When |
| --- | --- |
| ``MixlError/modelNotSupported(model:backend:)`` | Wrong model identifier for the client (e.g. Qwen model on ``LocalClient``). |
| ``MixlError/localModelUnavailable(reason:message:)`` | Correct client and model, but the device cannot run inference. See ``LocalModelUnavailabilityReason``. |
| ``MixlError/unsupportedParameter(_:)`` | Semantic mismatch: `tools`, JSON `response_format`, or tool messages (see table above). |
| ``MixlError/localInferenceFailed(_:)`` | Availability checks passed, but Foundation Models inference failed. |

Cloud-specific errors (``MixlError/httpError(statusCode:apiError:)``, ``MixlError/network(_:)``, etc.) originate from ``MixLayerClient`` only.

## Stateless sessions

Each `chat.create` or `chat.createStream` call creates a new Foundation Models `LanguageModelSession`. Mixl does not persist conversation state between requests. Include full message history in every call, the same as stateless cloud usage.

System messages are mapped to session instructions; user and assistant turns are formatted into a single prompt string for the final user message.

## Testing

Inject a test double through ``LocalClient/init(service:)``. The `MixlTesting` product provides `MockMixlService`—the same pattern as ``MixLayerClient/init(apiKey:baseURL:session:service:)``.

```swift
import Mixl
import MixlTesting

if #available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, tvOS 26.0, *) {
    let mock = MockMixlService()
    await mock.setStubbedResponse(/* ... */)

    let client = LocalClient(service: mock)
    _ = try await client.chat.create(model: .appleFoundation, messages: [.user("Hi")])
}
```

## See Also

- ``LocalClient``
- ``LocalModelSupport``
- ``Model/appleFoundation``
- ``MixlModelProvider``
- ``MixlService``
