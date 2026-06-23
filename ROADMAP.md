# Mixl Roadmap

Phases 1–6 (`0.1.0`–`0.6.0`) are **shipped**. Later items are **sketches** — not implemented until they land in code. See **Potential Use Cases** for product ideas under consideration.

---

## Phase 1 (shipped — `0.1.0`)

- **`MixLayerClient`** — cloud-only entry point for MixLayer’s OpenAI-compatible API (`https://models.mixlayer.ai/v1`).
- **`MixlChatCompletionsService`** — `chat.create` and `chat.createStream` with typed sampling, tools, and response-format parameters.
- **`MixlService` / `MixLayerAPIService`** — `URLSession` backend, SSE streaming, cancellation, injectable session for tests.
- **MixLayer-supported parameters** — `thinking`, `reasoningEffort`, penalties, `maxCompletionTokens`, `stop`, `seed`, `tools`, `responseFormat` (text, JSON object, JSON schema); omits unsupported OpenAI params (see `MIXLAYER.md`).
- **Reasoning** — `reasoningContent` on messages and stream deltas; docs aligned with [MixLayer reasoning](https://docs.mixlayer.com/reasoning).
- **`MixlError`** — typed errors with OpenAI-style API error envelope parsing.
- **Types** — `Model` (Qwen identifiers), `Message`, tool calling + JSON Schema codables.
- **`MixlTesting`** — `MockMixlService` for unit tests.
- **`MixlExamples`** — interactive CLI (non-thinking, reasoning modes, tools) using `Model.qwen3_5_4b_free`.
- **Docs & packaging** — README, `MIXLAYER.md`, `AGENTS.md`, DocC catalog, `PrivacyInfo.xcprivacy`, GitHub Actions CI on macOS.
- **Release** — public repo [`mutantsoup/mixl-swift`](https://github.com/mutantsoup/mixl-swift), tag [`0.1.0`](https://github.com/mutantsoup/mixl-swift/releases/tag/0.1.0).

---

## Phase 2 (shipped — `0.2.0`)

- **`LocalClient`** — on-device inference via Apple’s **Foundation Models** framework (`LanguageModelSession` / `SystemLanguageModel`), same `chat.create` / `createStream` API shape as `MixLayerClient` (no API key).
- **`Model.appleFoundation`** — `apple/foundation` identifier with `Model.provider` routing metadata for Phase 3.
- **`LocalInferenceService`** — conforms to **`MixlService`** (shared by cloud and local clients).
- **Availability** — `LocalModelSupport` with distinct **unsupported** vs **unavailable** errors; `@available(iOS 26, macOS 26, …)` + `#if canImport(FoundationModels)` for CI on older macOS runners.
- **Streaming** — local `createStream` via Foundation Models `streamResponse`.
- **Stateless** — new session per request.
- **`MixlExamples`** — local examples menu (no API key); cloud menu unchanged.
- **Docs** — README + `MIXLAYER.md` local backend section.

---

## Phase 3 (shipped — `0.3.0`)

- **`MixlClient` orchestrator** — routes `chat.create` / `createStream` to **MixLayer cloud** or **local** based on `Model` (and availability). Conforms to `MixlService`, so it can be injected anywhere a backend is expected.
- **`MixlRouter` protocol** with `MixlRoutingContext` / `MixlRoutingDecision`, plus **`MixlDefaultRouter`** — routes `.appleFoundation` to local, everything else to cloud.
- **Availability-aware default routing** — when a request targets local but on-device inference is unavailable, the default router throws `MixlError.localModelUnavailable` instead of silently routing `apple/foundation` to the cloud (which does not host it). Custom routers can implement cloud substitution via `MixlRoutingContext.isLocalAvailable`.
- **Backend escape hatches** — `MixlClient.cloud` (`MixLayerClient`) and platform-gated `MixlClient.local` (`LocalClient`) bypass the router for guaranteed targeting.
- **`MixlExamples`** — unified orchestrator menu demonstrating router-based cloud/local routing, the direct `client.cloud` / `client.local` accessors, and a run-all option.
- Same public types: `Message`, `Model`, `ChatCompletionRequest`, etc.

---

## Phase 4 (shipped — `0.4.0`)

- **Custom routers** under `Sources/Mixl/Routers/`: **`MixlLogicRouter`** (inline `async`/`throws` closure), **`MixlFallbackRouter`** (falls back to a configured cloud model when on-device inference is unavailable), and **`MixlPatternRouter`** (regex/PII gating, delegating to a default router when no rule matches).
- **`MixlPatternRule`** with bundled best-effort PII rule factories: `.email`, `.usSSN`, `.creditCard`, `.phoneUS`, `.ipv4`.
- **`ChatCompletionRequest.copy(withModel:)`** and **`Model.routed`** for routers that rewrite the target model.
- **`proxy/`** — a dependency-free Node.js reference **key proxy** (standalone server plus AWS Lambda and GCP Cloud Functions handlers over a shared forwarding core) that keeps the MixLayer API key server-side, with masked per-request logging. The app uses `MixLayerClient` unchanged apart from `apiKey` (a user token) and `baseURL`.
- **`MixlExamples`** — per-category source files, a `Quit` option in every menu, and a proxy run mode (`MIXLAYER_BASE_URL`) with an explicit `PROXY` / `DIRECT` banner.
- **Docs** — README **Securing Your API Key** section, DocC <doc:Routing> article.
- **Fix** — `MixlFallbackRouter` preserves the primary router's transformed local request when falling back to the cloud.

---

## Phase 5 (shipped — `0.5.0`)

- **`MixlRequestTransform`** — a transform-only protocol for rewriting a `ChatCompletionRequest` before it is routed. Transforms answer "what payload?"; the `MixlRouter` still owns "which backend?".
- **`MixlTransform`** — inline closure transform with a **`.mapContent(_:)`** convenience for rewriting message text; **`MixlClient(… transforms:)`** applies an ordered chain before routing (a throwing transform aborts the request).
- **`ChatCompletionRequest.copy(withMessages:)`** and **`.mappingContent(_:)`** helpers, organized with the transform types under `Sources/Mixl/Transforms/`.
- **Docs** — DocC <doc:Transforms> article; `MixlExamples` transform-chain example (filler stripping → redaction → logging).

---

## Phase 6 (shipped — `0.6.0`)

- **Declarative prompt API** (`Sources/Mixl/Declarative/`) — a SwiftUI-style layer over `MixlClient`, pure syntactic sugar that resolves to a `ChatCompletionRequest` (plus an optional per-prompt router and transforms) and runs through the existing pipeline. The imperative `chat.create` API is unchanged.
- **`PromptContent`** + **`PromptBuilder`** with leaf components `System` / `User` / `Assistant` / `ToolReply` (and raw `Message` passthrough), the **`Prompt`** container, and chainable modifiers covering the full request surface (sampling, thinking/reasoning, tools, response format), resolving innermost-wins like Apple's Foundation Models profiles.
- **Routing & transform modifiers** (`.router`, `.fallback(to:)`, `.transform`, `.mapContent`) bridge Phases 4–5 into the declarative surface.
- **`PromptComponent`** (reusable `body`-based prompts), **`PromptModifier`** (custom modifiers), a **tool-schema DSL** (`FunctionTool` / `Field`), **`MixlClient.run` / `.stream`** execution, and **`resolvedMessages()` / `resolvedTools()`** for previewing a composed prompt.
- **`MixlClient`** refactored to a shared internal route/dispatch core used by both the imperative and declarative paths.
- **Docs** — DocC <doc:Declarative> article, README Quick Start section; `MixlExamples` dedicated **Declarative API Examples** menu (cloud, on-device, and a two-model outline → paragraph chain).

---

## Potential Use Cases

Sketches only — **not implemented** until they land in code. More items will be added over time.

### Cloud-assisted prompt compression for local inference

**Problem:** On-device models have a smaller effective context window (e.g. ~4k tokens today). A long prompt (e.g. 10k tokens) may be **truncated** by the local stack, which is **lossy** and drops important context.

**Potential solution:** Use the orchestrator in a **two-step pipeline**:

1. **Cloud (MixLayer)** — Send the full prompt (or a structured summary request) to a capable cloud model with an instruction like: *compress this conversation/context to fit within N tokens while preserving facts, constraints, and task intent.*
2. **Local (Foundation Models)** — Run the **actual inference** on the compressed prompt on-device.

**Why this fits Mixl:** The value of bundling Foundation Models into Mixl is not to replace Apple’s framework, but to offer **one orchestration layer** that can combine MixLayer’s larger context / reasoning with on-device execution.

**Privacy angle:** Sensitive **final inference** (and user data in the answer path) stays on-device. Cloud step only sees what the app chooses to send for compression (apps may redact, segment, or use a less sensitive subset). Product/policy decisions about what may leave the device are app-level; Mixl would expose the mechanism, not mandate trust boundaries.

**Open design questions:**

- Token budget API: who specifies target size (4k, configurable)?
- Compression as explicit orchestrator method vs automatic when `model` is local and input exceeds budget?
- Streaming: compress synchronously first, then stream local response?
- Cost/latency: extra cloud round-trip before every local call when over budget.
- Evaluation: how to measure compression quality (tests, golden prompts)?
- Fallback: if compression fails, truncate, reject, or route entirely to cloud?

**Status:** Concept only — no built-in compression or token-budget helper yet. The building blocks now exist: the `MixlClient` orchestrator (Phase 3), request transforms (Phase 5), and declarative chaining across models (Phase 6) make a manual cloud-compress → local-infer pipeline straightforward to assemble today. A first-class API would add an explicit token-budget and compression step on top.
