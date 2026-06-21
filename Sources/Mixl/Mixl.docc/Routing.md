# Routing requests across backends

Route chat completions between the MixLayer cloud and on-device local backends with ``MixlClient`` and a ``MixlRouter`` policy.

## Overview

``MixlClient`` is a unified orchestrator that conforms to ``MixlService`` and exposes the same `chat.create` / `chat.createStream` API as ``MixLayerClient`` and ``LocalClient``. For each request it consults a ``MixlRouter`` to decide which backend handles the call and what payload to send.

```swift
import Mixl

// Default routing: `.appleFoundation` -> local, everything else -> cloud.
let client = MixlClient(apiKey: "your-api-key")

let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [.user("Hello!")]
)
```

A router receives the request plus a ``MixlRoutingContext`` (which reports whether on-device inference is currently available) and returns a ``MixlRoutingDecision`` — either `.cloud` or `.local`, each carrying the request payload to submit. Because the decision carries a payload, a router can rewrite the request (for example, swap in a different ``Model``) as part of deciding where it goes. Use ``Model/routed`` as the request model when you want the router to choose the concrete model dynamically.

### Default routing

``MixlDefaultRouter`` is used when you do not supply a router. It sends ``Model/appleFoundation`` requests to the local backend and everything else to the cloud. It is **availability-aware**: if a request targets the local backend while on-device inference is unavailable, it throws ``MixlError/localModelUnavailable(reason:message:)`` rather than silently swapping to a cloud model the MixLayer backend does not host.

### Bypassing the router

To target a backend directly and skip routing entirely, use the ``MixlClient/cloud`` and platform-gated ``MixlClient/local`` accessors:

```swift
let cloudOnly = try await client.cloud.chat.create(model: .qwen3_5_27b, messages: messages)
let localOnly = try await client.local.chat.create(model: .appleFoundation, messages: messages)
```

## Built-in routers

Supply a custom policy through the `router:` parameter:

```swift
let client = MixlClient(apiKey: "your-api-key", router: MixlFallbackRouter())
```

### Logic router

``MixlLogicRouter`` wraps a closure, letting you express any policy inline without declaring a new type. The closure is `async` and `throws`, so it can perform checks (latency, cost ceilings, system load) before deciding.

```swift
let router = MixlLogicRouter { request, context in
    let length = request.messages.compactMap { $0.content?.count }.reduce(0, +)
    if length < 100, context.isLocalAvailable {
        return .local(request.copy(withModel: Model.appleFoundation.rawValue))
    }
    return .cloud(request.copy(withModel: Model.qwen3_5_4b_free.rawValue))
}
```

### Fallback router

``MixlFallbackRouter`` keeps requests flowing when on-device inference is down. It consults a primary router (``MixlDefaultRouter`` by default); when the primary routes to local but local is unavailable — or throws ``MixlError/localModelUnavailable(reason:message:)`` — it rewrites the request to a configured cloud model and routes to the cloud instead. Any payload transformation the primary applied to the local request is preserved.

```swift
let router = MixlFallbackRouter(fallbackCloudModel: .qwen3_5_4b_free)
```

### Pattern router

``MixlPatternRouter`` evaluates an ordered list of ``MixlPatternRule`` values (each a precompiled regular expression) against the prompt text and routes on the first match. It is intended for privacy/compliance gating — for example, keeping prompts that contain sensitive data on-device. When no rule matches, it delegates to a `defaultRouter`.

A starter set of best-effort rule factories is bundled for common PII categories — ``MixlPatternRule/email(name:decision:)``, ``MixlPatternRule/usSSN(name:decision:)``, ``MixlPatternRule/creditCard(name:decision:)``, ``MixlPatternRule/phoneUS(name:decision:)``, and ``MixlPatternRule/ipv4(name:decision:)``. Each takes only the routing decision:

```swift
let keepLocal: @Sendable (ChatCompletionRequest) -> MixlRoutingDecision = { request in
    .local(request.copy(withModel: Model.appleFoundation.rawValue))
}

let router = MixlPatternRouter(rules: [
    .email(decision: keepLocal),
    .usSSN(decision: keepLocal),
    .creditCard(decision: keepLocal)
])
```

> Important: Regular-expression detection is approximate. The bundled rules favor catching sensitive data over precision and may produce false positives or miss exotic formats; they perform no semantic validation (for example, no Luhn check on card numbers). For custom patterns, use ``MixlPatternRule/init(name:pattern:options:decision:)``, which throws on an invalid pattern.

### Composing routers

``MixlFallbackRouter`` and ``MixlPatternRouter`` both accept an inner router, so policies stack. For example, gate on PII first, then fall back to the cloud when local is down:

```swift
let router = MixlPatternRouter(
    rules: [.email(decision: keepLocal)],
    defaultRouter: MixlFallbackRouter()
)
```

## Topics

### Orchestrator

- ``MixlClient``

### Router protocol

- ``MixlRouter``
- ``MixlRoutingContext``
- ``MixlRoutingDecision``
- ``MixlDefaultRouter``

### Custom routers

- ``MixlLogicRouter``
- ``MixlFallbackRouter``
- ``MixlPatternRouter``
- ``MixlPatternRule``
