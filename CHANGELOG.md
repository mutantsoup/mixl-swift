# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-15

### Added

- MixLayer Chat Completions SDK for Apple platforms (iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+).
- `MixLayerClient` with `chat.create` and `chat.createStream` APIs.
- Type-safe models for MixLayer Qwen identifiers, messages, tools, and JSON Schema declarations.
- Extended thinking/reasoning support via `thinking`, `reasoningEffort`, and `reasoningContent`.
- SSE streaming parser with cancellation support.
- Supported MixLayer request parameters: sampling, penalties, `maxCompletionTokens`, `maxTokens`, `stop`, `seed`, `tools`, and `responseFormat` (text, JSON object, JSON schema).
- `MixLayerError` with OpenAI-compatible API error envelope parsing.
- `URLSession` injection on `MixLayerClient` for testing.
- Unit tests with `MockURLProtocol` and optional live integration tests via `MIXLAYER_API_KEY`.
- Interactive `MixlExamples` CLI demonstrating non-thinking completions, streaming reasoning modes (`thinking: true` and each `reasoningEffort` level), and tool calling — uses `Model.qwen3_5_4b_free` for free-tier testing.
- GitHub Actions CI workflow.
- `MixlTesting` library product with ``MockMixLayerService`` for unit tests.
- DocC documentation catalog (`Mixl.docc`).
- `PrivacyInfo.xcprivacy` for App Store SDK privacy manifest requirements.

### Notes

- MixLayer does not support `tool_choice`; the SDK intentionally omits it. See [MIXLAYER.md](MIXLAYER.md#ml-ref-compat).
- `reasoning_effort` levels are reserved for future upstream behavior per [MixLayer reasoning docs](https://docs.mixlayer.com/reasoning); see [MIXLAYER.md](MIXLAYER.md#ml-ref-thinking) for Mixl usage notes.

## [0.2.0] - 2026-06-17

### Added

- **`LocalClient`** — on-device chat completions via Apple Foundation Models (iOS 26+, macOS 26+), mirroring `MixLayerClient`’s `chat.create` / `chat.createStream` API without an API key.
- **`Model.appleFoundation`** (`apple/foundation`) and **`MixlModelProvider`** for backend routing metadata.
- **`LocalModelSupport`** — preflight availability checks with distinct `modelNotSupported`, `localModelUnavailable`, and `unsupportedParameter` errors.
- **`MixlService`** — shared inference protocol for cloud (`MixLayerAPIService`) and local (`LocalInferenceService`) backends (renamed from `MixLayerService`).
- Local streaming via Foundation Models `streamResponse`.
- Gated local integration test (`testLocalClientIntegrationTest`) when Foundation Models SDK is linked and on-device model is available.
- **`MixlExamples`** local examples menu; cloud examples unchanged.
- Local backend documentation in README and `MIXLAYER.md`.
- DocC <doc:LocalInference> article and expanded symbol documentation for ``LocalClient``, ``LocalModelSupport``, ``MixlModelProvider``, and local error types.

### Changed

- **`MixLayerService`** renamed to **`MixlService`** — reflects shared cloud + local inference interface.
- **`MixLayerError`** renamed to **`MixlError`**, with cloud helpers in `API/MixLayerAPIErrorResponse.swift` and local reasons in `Local/LocalModelUnavailabilityReason.swift`.
- **`MockMixLayerService`** renamed to **`MockMixlService`** in the `MixlTesting` product.
- Adopted consistent type naming: **`Mixl*`** (framework/shared), **`MixLayer*`** (cloud), **`Local*`** (on-device)—including `MixlChatCompletionsService`, `MixlModelProvider`, `MixLayerAPIService`, `LocalInferenceService`, and related internals.
- **Local parameter policy:** cloud-only sampling/reasoning parameters are stripped with `os.Logger` info messages; `tools`, JSON `response_format`, and tool messages remain strict (`MixlError.unsupportedParameter`).

## [0.3.0] - 2026-06-17

### Added

- **`MixlClient`** — unified orchestrator that routes `chat.create` / `chat.createStream` to the MixLayer cloud or on-device local backend based on the requested `Model`. Conforms to `MixlService` and accepts injectable cloud/local services for testing.
- **`MixlRouter`** protocol with `MixlRoutingContext` and `MixlRoutingDecision`, plus **`MixlDefaultRouter`** for automatic model-based routing.
- **Availability-aware default routing** — `MixlDefaultRouter` throws `MixlError.localModelUnavailable` when a request targets `.appleFoundation` but on-device inference is unavailable, rather than routing the unsupported model to the cloud. An injected local service is treated as available so test doubles route deterministically.
- **`MixlClient.cloud`** and platform-gated **`MixlClient.local`** accessors to bypass the router and target a specific backend.
- **`MixlExamples`** unified orchestrator menu demonstrating router-based cloud/local routing, the direct `client.cloud` / `client.local` accessors, and a run-all option.
- `MixlClientTests` covering default/custom routing, streaming, availability-aware fail-fast behavior, and routing-context computation.

## [0.4.0] - 2026-06-21

### Added

- **`MixlLogicRouter`** — routes via a custom `async`/`throws` closure, for inline policies without declaring a new type.
- **`MixlFallbackRouter`** — falls back to a configurable cloud model when a primary router targets local but on-device inference is unavailable (or throws `localModelUnavailable`), preserving any payload transformation the primary applied.
- **`MixlPatternRouter`** and **`MixlPatternRule`** — route on ordered, precompiled regular-expression rules against prompt text (e.g. PII/compliance gating), delegating to a default router when no rule matches.
- **Bundled best-effort PII rule factories** on `MixlPatternRule`: `.email`, `.usSSN`, `.creditCard`, `.phoneUS`, and `.ipv4` — non-throwing convenience constructors that take only the routing decision.
- **`ChatCompletionRequest.copy(withModel:)`** — returns a copy of a request with a different model identifier, for routers that rewrite the target model.
- New router types organized under `Sources/Mixl/Routers/` (one type per file).
- **`proxy/`** — a runnable, dependency-free Node.js reference key proxy (standalone server plus AWS Lambda and GCP Cloud Functions handlers over a shared forwarding core) that keeps the MixLayer API key server-side; the app uses `MixLayerClient` unchanged apart from `apiKey` (a user token) and `baseURL`. Includes per-request logging with all keys/tokens masked (toggle with `PROXY_LOG`).
- README **Securing Your API Key** section — client/server/BYOK guidance, a backend-proxy walkthrough, and operational hygiene.
- DocC <doc:Routing> article, a Routing topics group, and a README routing section and feature entry.
- `MixlPatternRuleCommonTests` covering each bundled PII pattern (positive/negative samples), decision wiring, and router integration.

### Changed

- **`MixlExamples`** — added a **Quit** option to every menu so the app can be exited from any submenu, via a shared `quit()` helper; split the examples source into per-category files.
- **`MixlExamples`** — added a proxy run mode: setting `MIXLAYER_BASE_URL` (with an optional `MIXLAYER_AUTH_TOKEN`) routes the cloud/orchestrator examples through a key proxy with a user token instead of requiring `MIXLAYER_API_KEY`. Menus show an explicit `🔌 PROXY MODE` / `🔑 DIRECT MODE` banner (with the masked credential and its source env var) so it's clear which path is active. The existing direct `MIXLAYER_API_KEY` mode is unchanged.

### Fixed

- **`MixlFallbackRouter`** now copies the primary router's transformed local request when falling back to the cloud, instead of the original untransformed request.

## [0.5.0] - 2026-06-23

### Added

- **`MixlRequestTransform`** — a transform-only protocol for rewriting a `ChatCompletionRequest` before it is routed. Transforms answer "what payload?" and run ahead of the `MixlRouter`, which still owns "which backend?"; they never select a backend.
- **`MixlTransform`** — inline closure-based transform (the sibling of `MixlLogicRouter`), with a **`MixlTransform.mapContent(_:)`** convenience for the common case of rewriting message text. Messages with `nil` content pass through untouched and all other message fields are preserved.
- **`MixlClient(… transforms:)`** — an ordered transform chain applied before routing; the output of one transform feeds the next, and a throwing transform aborts the request before it reaches the router or any backend. The direct `cloud` / `local` accessors bypass both the router and the transform chain.
- **`ChatCompletionRequest.copy(withMessages:)`** and **`ChatCompletionRequest.mappingContent(_:)`** — helpers for transforming a request's messages while leaving sampling and routing parameters untouched.
- New transform types organized under `Sources/Mixl/Transforms/` (one type per file).
- **`MixlExamples`** unified orchestrator menu item demonstrating a transform chain — voice-transcription filler stripping, sensitive-term redaction, and a final-prompt logging transform composed left-to-right.
- DocC <doc:Transforms> article, a Transforms topics group, and a README feature entry.
- `MixlRequestTransformTests` covering chain ordering, routing-context plumbing, throwing-aborts-the-request, streaming, and `mapContent` field-preservation semantics.

### Changed

- **`MixlExamples`** — the streaming-reasoning example now uses a cleaner prompt (dropped the redundant "solve it step-by-step", since the reasoning stream already shows the working), a lower `temperature` (`0.5`), and a `maxCompletionTokens` ceiling as a guardrail against runaway reasoning loops on the free-tier model.

[0.5.0]: https://github.com/mutantsoup/mixl-swift/releases/tag/0.5.0
[0.4.0]: https://github.com/mutantsoup/mixl-swift/releases/tag/0.4.0
[0.3.0]: https://github.com/mutantsoup/mixl-swift/releases/tag/0.3.0
[0.2.0]: https://github.com/mutantsoup/mixl-swift/releases/tag/0.2.0
[0.1.0]: https://github.com/mutantsoup/mixl-swift/releases/tag/0.1.0
