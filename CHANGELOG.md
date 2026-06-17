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

[0.2.0]: https://github.com/mutantsoup/mixl-swift/releases/tag/0.2.0
[0.1.0]: https://github.com/mutantsoup/mixl-swift/releases/tag/0.1.0
