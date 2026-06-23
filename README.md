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
- [x] **Unified Routing**: `MixlClient` orchestrates a single API across cloud and on-device backends via a pluggable `MixlRouter` — model-based default, inline closure (`MixlLogicRouter`), cloud fallback (`MixlFallbackRouter`), and regex/PII gating (`MixlPatternRouter`) with bundled PII rule factories.
- [x] **Request Transforms**: Rewrite the request payload before it is routed via a chain of `MixlRequestTransform` — clean up voice-transcribed prompts, redact sensitive terms, or inject a shared preamble. Use `MixlTransform` for inline closures and `MixlTransform.mapContent` to edit message text.
- [x] **Declarative API**: Compose requests with a SwiftUI-style layer over `MixlClient` — composed content (`System`/`User`/`Assistant`), chainable modifiers (`.temperature`, `.reasoning`, `.tools`, …), reusable `PromptComponent` types, and custom `PromptModifier` types — run with `client.run` / `client.stream`. Pure sugar over the existing pipeline.

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

> **Security:** The hardcoded key literal above is illustrative only. Never hardcode or commit your MixLayer API key, and do not embed it in a shipped app. See [Securing Your API Key](#securing-your-api-key).

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

### 7. Unified Routing with `MixlClient`

`MixlClient` exposes the same `chat.create` / `chat.createStream` API as the cloud and local clients, but routes each request to the appropriate backend through a `MixlRouter`. By default, `.appleFoundation` requests go on-device and everything else goes to the cloud:

```swift
import Mixl

let client = MixlClient(apiKey: "your-mixlayer-api-key")

// Routed automatically by the requested model.
let response = try await client.chat.create(
    model: .qwen3_5_27b,
    messages: [.user("Hello!")]
)

// Bypass the router to target a backend directly.
let cloudOnly = try await client.cloud.chat.create(model: .qwen3_5_27b, messages: [.user("Hi")])
```

Supply a custom policy with the `router:` parameter. Built-in routers:

**`MixlLogicRouter`** — express any policy inline as an `async`/`throws` closure:

```swift
let client = MixlClient(apiKey: key, router: MixlLogicRouter { request, context in
    let length = request.messages.compactMap { $0.content?.count }.reduce(0, +)
    if length < 100, context.isLocalAvailable {
        return .local(request.copy(withModel: Model.appleFoundation.rawValue))
    }
    return .cloud(request.copy(withModel: Model.qwen3_5_4b_free.rawValue))
})
```

**`MixlFallbackRouter`** — automatically fall back to a cloud model when on-device inference is unavailable:

```swift
let client = MixlClient(apiKey: key, router: MixlFallbackRouter(fallbackCloudModel: .qwen3_5_4b_free))
```

**`MixlPatternRouter`** — keep prompts containing sensitive data on-device using regex rules. A starter set of best-effort PII rule factories is bundled (`.email`, `.usSSN`, `.creditCard`, `.phoneUS`, `.ipv4`):

```swift
let keepLocal: @Sendable (ChatCompletionRequest) -> MixlRoutingDecision = { request in
    .local(request.copy(withModel: Model.appleFoundation.rawValue))
}

let client = MixlClient(apiKey: key, router: MixlPatternRouter(rules: [
    .email(decision: keepLocal),
    .usSSN(decision: keepLocal),
    .creditCard(decision: keepLocal)
]))
```

`MixlFallbackRouter` and `MixlPatternRouter` each accept an inner router, so policies compose (e.g. gate on PII first, then fall back to cloud when local is down). Bundled PII rules are best-effort and perform no semantic validation (no Luhn check on cards); for custom patterns use the throwing `MixlPatternRule(name:pattern:options:decision:)` initializer.

See the DocC <doc:Routing> article (**Product → Build Documentation** in Xcode) for the full routing guide.

### 8. Declarative Composition with `client.run`

`MixlClient` also offers a SwiftUI-style declarative API as **pure syntactic sugar** over the same pipeline — the imperative `chat.create` API is unchanged. Compose content with a `@PromptBuilder` (with inline `if` / `for`), configure it with chainable modifiers, and execute with `client.run` / `client.stream`:

```swift
import Mixl

let client = MixlClient(apiKey: "your-mixlayer-api-key")

let response = try await client.run(.qwen3_5_27b) {
    System("You are concise.")
    if includeContext { User(contextBlob) }
    User("Explain routing in one sentence.")
}
```

Modifiers cover the full request surface (`.temperature`, `.topP`, `.reasoning`, `.thinking`, `.maxCompletionTokens`, `.stop`, `.responseFormat`, `.tools { … }`, …), and the routing/transform features are exposed as modifiers too (`.router`, `.fallback(to:)`, `.transform`, `.mapContent`). Precedence follows Apple's Foundation Models profiles: the innermost modifier wins.

Define reusable, parameterized prompts by conforming to `PromptComponent` (the analog of SwiftUI's `View` / Foundation Models' `DynamicInstructions`):

```swift
struct SupportPrompt: PromptComponent {
    var question: String
    var history: [Message] = []

    var body: some PromptContent {
        System("You are a concise support agent.")
        for message in history { message }
        User(question)
    }
}

let answer = try await client.run(.qwen3_5_27b, SupportPrompt(question: question))
```

Because each `run` is one request, chaining is ordinary sequencing — run one prompt, feed its output into the next, optionally on a different model (e.g. an on-device draft refined in the cloud). See the DocC <doc:Declarative> article for the full guide, custom `PromptModifier` types, and the tool-schema DSL.

---

## Securing Your API Key

Your MixLayer API key grants billable access to your account — treat it like a password. **Never hardcode it in source, commit it to version control, or embed it in an app you ship to users.** Keep real keys in `.gitignore`d configuration and load them at runtime.

### Client apps (iOS, macOS, etc.): proxy through your own backend

Any secret shipped inside a distributed app **can be extracted** — by inspecting the binary, dumping memory, or intercepting TLS traffic — even if it is obfuscated or stored in the Keychain at runtime. There is no way to safely embed a long-lived MixLayer key in a client app.

Instead, keep the key on a server you control and have the app call *your* backend, which calls MixLayer on its behalf:

```
App ──(your per-user auth)──> Your backend ──(MixLayer key)──> MixLayer API
```

This is the only approach that actually protects the key, and it lets you add per-user authentication, rate limiting, usage quotas, abuse monitoring, and key rotation without shipping an app update. `MixLayerClient` accepts a custom `baseURL`, so the app can point Mixl at your proxy:

```swift
let client = MixLayerClient(
    apiKey: userSessionToken,                          // your backend's token — NOT the MixLayer key
    baseURL: URL(string: "https://api.yourapp.com/mixlayer/v1")!
)
```

On-device inference needs no API key at all: routing sensitive or offline work to `LocalClient` / `Model.appleFoundation` (directly or via `MixlClient`) keeps it off the network entirely.

#### Example: a minimal key proxy

A runnable, dependency-free reference proxy ships in **[`proxy/`](proxy/)** — a standalone Node server plus AWS Lambda and GCP Cloud Functions handlers, sharing one forwarding core. It's starter code (the auth and rate-limit hooks are clearly-marked stubs to replace); see [`proxy/README.md`](proxy/README.md).

Because MixLayer's API is OpenAI-compatible and `MixLayerClient` lets you override `baseURL`, the proxy can be a thin authenticated pass-through. **The app keeps using Mixl unchanged** — only two constructor arguments differ: `apiKey` carries the user's session token (not the MixLayer key), and `baseURL` points at your proxy. Every other call (`chat.create`, streaming, tools, reasoning, error handling, routing) is identical.

```
iOS app                              Your proxy                          MixLayer
───────                              ──────────                          ────────
MixLayerClient(apiKey: userToken,  ─► POST /mixlayer/v1/chat/completions
               baseURL: proxy)        1. verify userToken (your auth)
                                      2. rate-limit / quota check
                                      3. swap Authorization → real key  ─► models.mixlayer.ai
        ◄───────────────────────────  4. stream SSE chunks back  ◄──────── (token stream)
```

The app sends its user token in the `Authorization: Bearer` header (where Mixl puts `apiKey`); the proxy validates it and **overwrites that header** with the real MixLayer key before forwarding. The proxy must mirror MixLayer's path layout (Mixl appends `/chat/completions` to `baseURL`) and stream the `text/event-stream` body through without buffering, or token streaming breaks. Sketch (Vapor-flavored, illustrative):

```swift
app.post("mixlayer", "v1", "chat", "completions") { req async throws -> Response in
    try await req.auth.require(AppUser.self)             // 1. your per-user auth
    try await rateLimiter.check(for: req.userID)          // 2. throttle / quota

    var headers = HTTPHeaders()
    headers.bearerAuthorization = .init(token: Environment.get("MIXLAYER_API_KEY")!) // 3. real key
    headers.contentType = .json

    let upstream = try await req.client.post(             // 4. forward + stream back
        "https://models.mixlayer.ai/v1/chat/completions",
        headers: headers
    ) { $0.body = req.body.data }

    return Response(status: upstream.status, headers: upstream.headers,
                    body: .init(buffer: upstream.body ?? .init()))
}
```

App side — the only change from the Quick Start:

```swift
let client = MixLayerClient(
    apiKey: userSessionToken,                                  // your token, not the MixLayer key
    baseURL: URL(string: "https://api.yourapp.com/mixlayer/v1")!
)
```

This pass-through isn't Swift-specific: style A is ~30 lines as a serverless function (Cloudflare Worker, Vercel, Lambda) in any language. Alternatively, expose your own higher-level endpoints (e.g. `POST /summarize`) and call MixLayer from the server — using Mixl with the real key — when you want to cap models/tokens or post-process server-side.

### Server-side Swift, scripts, and development

When the key lives in a trusted environment (your server, CI, or a dev machine), load it from an environment variable or a secrets manager rather than a literal — as the `MixlExamples` CLI does:

```swift
guard let apiKey = ProcessInfo.processInfo.environment["MIXLAYER_API_KEY"], !apiKey.isEmpty else { /* … */ }
let client = MixLayerClient(apiKey: apiKey)
```

Use a git-ignored `.env` file for local dev and your platform's secrets manager (Vault, AWS/GCP/Azure, GitHub Actions secrets, etc.) in production.

### "Bring your own key" apps

If each user supplies *their own* MixLayer key, store it in the **Keychain** (never `UserDefaults` or a plist), request it over a secure channel, and never log or forward it. The key is the user's own, so the residual extraction risk is theirs — but the Keychain still protects it from other apps and casual inspection.

### Operational hygiene

- **Rotate** keys periodically, and immediately revoke any that may have leaked in the [MixLayer Console](https://console.mixlayer.com).
- Use **separate keys per environment** (dev / staging / production) so one can be revoked without disrupting the others.
- **Monitor usage** for anomalies and set spending limits where available.
- **Never log the key.** (The `MixlExamples` CLI masks all but the first and last four characters when echoing it.)

---

## Running the Examples

An interactive command-line app demonstrates MixLayer cloud completions (non-thinking, streaming reasoning, tool calling), local on-device Foundation Models examples, and unified `MixlClient` routing (model-based routing, direct `client.cloud` / `client.local` access, and a custom logic router).

**Cloud examples** use **`Model.qwen3_5_4b_free`** and require a MixLayer API key:

```bash
export MIXLAYER_API_KEY="your-api-key"
swift run MixlExamples
```

**Local examples** use **`Model.appleFoundation`**, require **macOS 26+ / iOS 26+** with Apple Intelligence enabled, and do not need an API key. Select option **2** from the main menu.

**Orchestrator examples** (option **3**) demonstrate `MixlClient` routing and require a cloud connection for the cloud routing path.

**Through the local key proxy (no API key on this side).** Instead of exporting `MIXLAYER_API_KEY`, you can run the [reference proxy](proxy/) with your real key and point the examples at it with `MIXLAYER_BASE_URL` — the examples then connect with a user token, exactly as a shipped app would:

```bash
# Terminal 1 — start the proxy with your real key (kept server-side):
cd proxy && MIXLAYER_API_KEY="your-api-key" npm start

# Terminal 2 — run the examples against the proxy, no API key here:
export MIXLAYER_BASE_URL="http://localhost:8787/mixlayer/v1"
export MIXLAYER_AUTH_TOKEN="any-user-token"   # optional; the reference proxy accepts any non-empty token
swift run MixlExamples
```

When `MIXLAYER_BASE_URL` is set it takes precedence and the cloud/orchestrator menus show a `Via proxy:` banner. The existing direct mode (export `MIXLAYER_API_KEY`, no base URL) is unchanged.

Sign up for a free API key at the [MixLayer Console](https://console.mixlayer.com) if you do not have one. If neither a key nor a base URL is set, cloud examples print setup instructions; local examples remain available when the device supports them.

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
