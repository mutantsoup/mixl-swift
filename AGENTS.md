# Agent Guidelines & Project Instructions (`AGENTS.md`)

> [!NOTE]
> This file is the primary instruction manual for AI coding assistants working in the `mixl-swift` repository. Review this document before proposing or executing code changes.

---

## [AG-INDEX] Section Index
1. [Core Mission](#ag-mission) — `[AG-MISSION]`
2. [Architectural Blueprints](#ag-architecture) — `[AG-ARCH]`
3. [Swift Coding Conventions](#ag-conventions) — `[AG-CONV]`
4. [Mock to Production Sync Guidelines](#ag-sync) — `[AG-SYNC]`
5. [Implementation Checklist](#ag-checklist) — `[AG-CHECK]`
6. [Key Reference Files](#ag-references) — `[AG-REFS]`

---

## <a name="ag-mission"></a>[AG-MISSION] 1. Core Mission
Your task is to build and maintain **Mixl**, a lightweight, robust Swift library for working with the **MixLayer API** and on-device inference.
The library must wrap standard chat completions, tool calling, and streaming reasoning (thinking mode) in an elegant, native Swift interface matching Apple SDK standards (e.g., async/await, Decodable responses, and clean type-safety).

Mixl spans three backends behind one shared `MixlService` protocol — **cloud** (`MixLayerClient`), **on-device** Apple Foundation Models (`LocalClient`), and a unified **orchestrator** (`MixlClient`) that routes between them. On top of the orchestrator sit composable **routers** (backend selection), **request transforms** (payload rewriting), and a SwiftUI-style **declarative prompt API**. New work must preserve this layering and keep the imperative `chat.create` / `chat.createStream` API intact; the declarative layer is pure sugar over it.

---

## <a name="ag-architecture"></a>[AG-ARCH] 2. Architectural Blueprints

Design the library using a modular structure with unidirectional data flow and strong encapsulation:

```mermaid
graph TD
    Declarative["Declarative API (Prompt + modifiers, client.run/stream)"] --> Orchestrator
    Orchestrator[MixlClient] --> Transforms["Transforms (MixlRequestTransform)"]
    Orchestrator --> Router["Router (MixlRouter)"]
    Router --> Cloud[MixLayerClient]
    Router --> Local[LocalClient]
    Cloud --> ChatService[MixlChatCompletionsService]
    Local --> ChatService
    ChatService --> RequestModel[ChatCompletionRequest]
    Cloud --> NetworkEngine[MixLayerAPIService / URLSession]
    Local --> FoundationModels[LocalInferenceService / FoundationModels]
    NetworkEngine --> StreamParser[SSE Stream Parser]
    NetworkEngine --> DecodableResponse[ChatCompletionResponse / Decodable]
```

All three clients (`MixLayerClient`, `LocalClient`, `MixlClient`) conform to **`MixlService`** and expose the same `chat.create` / `chat.createStream` surface. Source is organized by layer:

* `Sources/Mixl/API/` — cloud backend (`MixLayerAPIService`, SSE parser, error envelope).
* `Sources/Mixl/Local/` — on-device backend (`LocalInferenceService`, `LocalClient`, availability, prompt building, request sanitizing).
* `Sources/Mixl/Routers/` — `MixlRouter` implementations (`MixlDefaultRouter`, `MixlLogicRouter`, `MixlFallbackRouter`, `MixlPatternRouter` + PII rule factories).
* `Sources/Mixl/Transforms/` — `MixlRequestTransform` and `MixlTransform`.
* `Sources/Mixl/Declarative/` — the declarative layer (`PromptContent`, `PromptBuilder`, components, modifiers, tool DSL, `MixlClient+Declarative`).
* `MixlClient` routes through a shared internal route/dispatch core reused by both the imperative and declarative entry points.

### 1. Networking Layer
* Use `URLSession` for network requests. Avoid third-party networking libraries like Alamofire unless explicitly requested.
* Use `async/await` for asynchronous operations.
* Wrap all networking errors in a custom `MixlError` enum.

### 2. Stream Parsing (SSE)
* Handle streaming with Swift's modern `AsyncThrowingStream`.
* Use `URLSession.bytes(for:)` to stream data.
* Parse Server-Sent Events (SSE) marked by the `data: ` prefix. Ignore empty or heart-beat lines.
* Extract reasoning chunks from `delta.reasoning_content` and text chunks from `delta.content` dynamically.

### 3. Model Modeling
* Model all payloads using Swift `Codable` structs matching the [MixLayer REST API schema](MIXLAYER.md#ml-ref-chat).
* Provide type-safe enums for model names (e.g. `Model.qwen3_5_27b`), message roles (`Role.user`, `Role.assistant`), and tool parameters.
* Model `reasoning_content` alongside `content` on chat message responses to support MixLayer's extended thinking mode natively.

---

## <a name="ag-conventions"></a>[AG-CONV] 3. Swift Coding Conventions

When writing Swift code, adhere strictly to these conventions:

* **Swift Concurrency**: Use `async/await` and task structures. Never use old completion handler patterns (`(Result<T, Error>) -> Void`).
* **API Design**: Follow Apple's Swift API Design Guidelines. Keep APIs expressive and type-safe.
* **Error Handling**: Throw typed errors. Never return `nil` or empty objects on failure.
* **Access Control**: Use `public` explicitly for public interfaces and `internal`/`private` to hide internals.
* **Property Wrappers / Codable**: Use custom coding keys or decoders where needed to map snake_case JSON keys to camelCase Swift properties.
* **No Placeholders**: Avoid writing dummy tests or unimplemented stubs. Always provide complete implementations.

---

## <a name="ag-sync"></a>[AG-SYNC] 4. Mock to Production Sync Guidelines

To prevent divergence between test environments and actual network clients:

* **Naming conventions**: Use **`Mixl*`** for framework-level shared types (`MixlService`, `MixlError`, `MixlChatCompletionsService`, `MixlModelProvider`, `MockMixlService`). Use **`MixLayer*`** for cloud-only types (`MixLayerClient`, `MixLayerAPIService`, `MixLayerAPIErrorResponse`). Use **`Local*`** for on-device types (`LocalClient`, `LocalInferenceService`, `LocalPromptBuilder`, `LocalModelSupport`). Shared OpenAI-compatible payload types (`Message`, `Model`, `ChatCompletionRequest`, etc.) remain unprefixed inside the `Mixl` module.
* **Interface Integrity**: The `MixlService` protocol acts as the source of truth. Any modifications or additions of API methods to `MixlService` must be made simultaneously in both `MixLayerAPIService` (production), `LocalInferenceService` (local), and `MockMixlService` (`MixlTesting` product).
* **Mock Actor Alignment**: `MockMixlService` (in `Sources/MixlTesting/`) is implemented as an `actor` to maintain thread-safe state access under strict concurrency checks. Keep its properties (such as `lastRequest`, `stubbedResponse`, and `stubbedError`) aligned with incoming requests and error stubs.
* **URLProtocol Validation**: When changing request parameter mappings in `MixLayerAPIService`, always write matching tests in `NetworkTests` using `MockURLProtocol` to assert HTTP headers, methods, endpoints, and body encodings.
* **Value Consistency**: Do not change request or response struct properties in test mock payloads without validating matching updates to production codables in the library target.

---

## <a name="ag-checklist"></a>[AG-CHECK] 5. Implementation Checklist

Use this checklist to track development milestones:

- [x] **Infrastructure Setup**
  - [x] Swift Package Manager (`Package.swift`) initialization.
  - [x] Xcode unit test bundle setup.
- [x] **Core Client Implementation**
  - [x] `MixLayerClient` initializer accepting API Key and optional host/URL override.
  - [x] Network client configuration with appropriate HTTP headers (`Authorization`, `Content-Type`).
- [x] **Models & Request/Response Types**
  - [x] Type-safe message structures: `Message`, `Role`, `Choice`, `Usage`.
  - [x] Support for reasoning fields: `reasoningContent` on messages and deltas.
  - [x] Strict tool calling structures: `Tool`, `FunctionCall`, `ToolCall`.
- [x] **API Services**
  - [x] Standard Chat Completions client method (`client.chat.create(...)`).
  - [x] Streaming completions returning `AsyncThrowingStream<ChatCompletionChunk, Error>`.
- [x] **Testing & Verification**
  - [x] Unit tests using XCTest mock HTTP responses.
  - [x] Integration tests using real API keys (gated by local env files).
- [x] **Examples & Licensing**
  - [x] Create interactive command-line app target (`MixlExamples`).
  - [x] Implement standard completion, streaming reasoning, and tool execution examples.
  - [x] Add standard MIT `LICENSE` file.
- [x] **Local Foundation Models**
  - [x] `LocalClient` with same API shape as `MixLayerClient` (no API key).
  - [x] `LocalInferenceService` conforming to `MixlService`.
  - [x] `Model.appleFoundation` and `MixlModelProvider` backend metadata.
  - [x] Availability checks and distinct unsupported vs unavailable errors.
  - [x] Stateless `LanguageModelSession` per request; streaming via `streamResponse`.
  - [x] Local examples and docs (`README`, `MIXLAYER.md`).
- [x] **Orchestrator & Routing Client**
  - [x] `MixlClient` orchestrator client conforming to `MixlService`.
  - [x] `MixlRouter` protocol defining routing decisions.
  - [x] `MixlDefaultRouter` for automatic model routing.
  - [x] Dynamic backend extensions for `.cloud` and platform-gated `.local`.
  - [x] Unified router examples in CLI.
- [x] **Custom Routers & Key Proxy** (`0.4.0`)
  - [x] `MixlLogicRouter`, `MixlFallbackRouter`, `MixlPatternRouter` under `Sources/Mixl/Routers/`.
  - [x] `MixlPatternRule` with bundled PII factories (`.email`, `.usSSN`, `.creditCard`, `.phoneUS`, `.ipv4`).
  - [x] `ChatCompletionRequest.copy(withModel:)` and `Model.routed`.
  - [x] `proxy/` reference key proxy (standalone + AWS Lambda + GCP) with masked logging.
  - [x] README "Securing Your API Key" section and DocC `Routing` article.
- [x] **Request Transforms** (`0.5.0`)
  - [x] `MixlRequestTransform` protocol and `MixlTransform` (with `.mapContent`) under `Sources/Mixl/Transforms/`.
  - [x] `MixlClient(transforms:)` chain applied before routing; `copy(withMessages:)` / `mappingContent(_:)`.
  - [x] DocC `Transforms` article and a transform-chain example.
- [x] **Declarative Prompt API** (`0.6.0`)
  - [x] `PromptContent` + `PromptBuilder`, leaf components, `Prompt`, and chainable modifiers under `Sources/Mixl/Declarative/`.
  - [x] `PromptComponent`, `PromptModifier`, tool-schema DSL (`FunctionTool` / `Field`).
  - [x] `MixlClient.run` / `.stream` execution and `resolvedMessages()` / `resolvedTools()` previewing.
  - [x] DocC `Declarative` article, README Quick Start section, and a dedicated examples menu.

---

## <a name="ag-references"></a>[AG-REFS] 6. Key Reference Files

* **API Specification Reference**: [MIXLAYER.md](MIXLAYER.md) — Contains REST endpoints, parameter guides, reasoning models, and tool details.
* **Roadmap**: [ROADMAP.md](ROADMAP.md) — Shipped phases (`0.1.0`–`0.6.0`) and use-case sketches under consideration.
* **Changelog**: [CHANGELOG.md](CHANGELOG.md) — User-visible changes per release; update for any user-facing change.
* **Contributing Guide**: [CONTRIBUTING.md](CONTRIBUTING.md) — Test/PR workflow and the mock/production sync rules.
* **Main Project Readme**: [README.md](README.md) — Main human onboarding, build, and example execution guide.
* **Examples Target Main**: [MixlExamples.swift](Sources/MixlExamples/MixlExamples.swift) — Interactive console loop; per-category files (`ExamplesApp+CloudExamples`, `+LocalExamples`, `+OrchestratorExamples`, `+DeclarativeExamples`, `+Support`).
* **DocC Catalog**: [Sources/Mixl/Mixl.docc/](Sources/Mixl/Mixl.docc/) — Articles for local inference, routing, transforms, and the declarative API.
* **Key Proxy**: [proxy/README.md](proxy/README.md) — Reference server-side key proxy (`0.4.0`).
* **License Agreement**: [LICENSE](LICENSE) — Standard MIT licensing details.
