# Transforming requests before they are sent

Rewrite the chat completion payload — clean up a prompt, redact sensitive terms, inject a preamble — with a chain of ``MixlRequestTransform`` values on ``MixlClient``.

## Overview

A request transform answers a different question than a ``MixlRouter``. A router decides *which backend* handles a call; a transform decides *what payload* is sent — independent of destination. ``MixlClient`` runs them in sequence:

```
request → [transform chain] → router (picks backend) → backend service
```

Transforms are **transform-only**: each returns a (possibly modified) ``ChatCompletionRequest`` and never selects a backend. Backend selection stays the exclusive job of the ``MixlRouter``. Because ``MixlRequestTransform/process(request:context:)`` is `async` and `throws`, a transform can call out to another service (for example, a fast on-device model to tidy up a voice transcript) or reject a request entirely by throwing.

```swift
import Mixl

let stripFiller = MixlTransform.mapContent { content in
    content.replacingOccurrences(
        of: "\\b(um+|uh+)\\b,?\\s*",
        with: "",
        options: [.regularExpression, .caseInsensitive]
    )
}

let client = MixlClient(apiKey: "your-api-key", transforms: [stripFiller])

// "um, what's the capital of France?" → "what's the capital of France?"
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [.user("um, what's the capital of France?")]
)
```

> Note: Transforms run only when a request flows through ``MixlClient``'s routed `chat.create` / `chat.createStream`. The direct ``MixlClient/cloud`` and ``MixlClient/local`` accessors bypass both the router *and* the transform chain.

## Inline transforms

``MixlTransform`` wraps a closure so you can express a transform without declaring a new type — the sibling of ``MixlLogicRouter`` on the transform side. The closure receives the request and the ``MixlRoutingContext``, so it can vary behavior by destination (for example, only redacting data when on-device inference is unavailable and the request is bound for the cloud).

```swift
let redactWhenCloudBound = MixlTransform { request, context in
    guard !context.isLocalAvailable else { return request }
    return request.mappingContent { $0.replacingOccurrences(of: "Project Cerberus", with: "[REDACTED]") }
}
```

### Rewriting message content

Most transforms just edit text. ``MixlTransform/mapContent(_:)`` maps a closure over the content of every message — messages with `nil` content (such as assistant tool-call messages) pass through untouched, and all other fields (role, name, reasoning content, tool calls) are preserved.

```swift
let upper = MixlTransform.mapContent { $0.uppercased() }
```

The same mapping is available directly on a request via ``ChatCompletionRequest/mappingContent(_:)``, which is handy inside a custom transform or when preparing a request by hand.

## Composing a chain

``MixlClient`` folds the request through the `transforms` array in order — the output of one transform becomes the input of the next. Keep individual transforms small and single-purpose, then stack them:

```swift
let client = MixlClient(
    apiKey: "your-api-key",
    transforms: [
        stripFiller,       // 1. normalize a voice transcript
        redactSecrets,     // 2. remove sensitive terms
        addStyleGuide      // 3. append shared instructions
    ]
)
```

A transform that throws aborts the request immediately: later transforms, the router, and every backend are skipped, and the error propagates to the caller. This makes a transform a natural place for a hard policy gate (for example, refusing a prompt that still contains a forbidden term after redaction).

## Custom transform types

For reusable logic, conform a type to ``MixlRequestTransform`` directly instead of using a closure:

```swift
struct SystemPreamble: MixlRequestTransform {
    let instructions: String

    func process(
        request: ChatCompletionRequest,
        context: MixlRoutingContext
    ) async throws -> ChatCompletionRequest {
        guard request.messages.first?.role != .system else { return request }
        return request.copy(withMessages: [.system(instructions)] + request.messages)
    }
}
```

## Topics

### Transform protocol

- ``MixlRequestTransform``
- ``MixlTransform``

### Request helpers

- ``ChatCompletionRequest/mappingContent(_:)``
- ``ChatCompletionRequest/copy(withMessages:)``
