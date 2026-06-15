# Agent Guidelines & Project Instructions (`AGENT.md`)

> [!NOTE]
> This file is the primary instruction manual for AI coding assistants working in the `mixl_ios` repository. Review this document before proposing or executing code changes.

---

## [AG-INDEX] Section Index
1. [Core Mission](#ag-mission) — `[AG-MISSION]`
2. [Architectural Blueprints](#ag-architecture) — `[AG-ARCH]`
3. [Swift Coding Conventions](#ag-conventions) — `[AG-CONV]`
4. [Implementation Checklist](#ag-checklist) — `[AG-CHECK]`
5. [Key Reference Files](#ag-references) — `[AG-REFS]`

---

## <a name="ag-mission"></a>[AG-MISSION] 1. Core Mission
Your task is to build and maintain **Mixl**, a lightweight, robust Swift/iOS library for working with the **MixLayer API**.
The library must wrap standard chat completions, tool calling, and streaming reasoning (thinking mode) in an elegant, native Swift interface matching Apple SDK standards (e.g., async/await, Decodable responses, and clean type-safety).

---

## <a name="ag-architecture"></a>[AG-ARCH] 2. Architectural Blueprints

Design the library using a modular structure with unidirectional data flow and strong encapsulation:

```mermaid
graph TD
    Client[MixLayerClient] --> ChatService[ChatCompletionsService]
    ChatService --> RequestModel[ChatCompletionRequest]
    ChatService --> NetworkEngine[NetworkEngine / URLSession]
    NetworkEngine --> StreamParser[SSE Stream Parser]
    NetworkEngine --> DecodableResponse[ChatCompletionResponse / Decodable]
```

### 1. Networking Layer
* Use `URLSession` for network requests. Avoid third-party networking libraries like Alamofire unless explicitly requested.
* Use `async/await` for asynchronous operations.
* Wrap all networking errors in a custom `MixLayerError` enum.

### 2. Stream Parsing (SSE)
* Handle streaming with Swift's modern `AsyncThrowingStream`.
* Use `URLSession.bytes(for:)` to stream data.
* Parse Server-Sent Events (SSE) marked by the `data: ` prefix. Ignore empty or heart-beat lines.
* Extract reasoning chunks from `delta.reasoning_content` and text chunks from `delta.content` dynamically.

### 3. Model Modeling
* Model all payloads using Swift `Codable` structs matching the [MixLayer REST API schema](file:///Users/danmurrelljr/Dev/mutantsoup/mixl_ios/MIXLAYER.md#ml-ref-chat).
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

## <a name="ag-checklist"></a>[AG-CHECK] 4. Implementation Checklist

Use this checklist to track development milestones:

- [ ] **Infrastructure Setup**
  - [ ] Swift Package Manager (`Package.swift`) initialization.
  - [ ] Xcode unit test bundle setup.
- [ ] **Core Client Implementation**
  - [ ] `MixLayerClient` initializer accepting API Key and optional host/URL override.
  - [ ] Network client configuration with appropriate HTTP headers (`Authorization`, `Content-Type`).
- [ ] **Models & Request/Response Types**
  - [ ] Type-safe message structures: `Message`, `Role`, `Choice`, `Usage`.
  - [ ] Support for reasoning fields: `reasoningContent` on messages and deltas.
  - [ ] Strict tool calling structures: `Tool`, `FunctionCall`, `ToolCall`.
- [ ] **API Services**
  - [ ] Standard Chat Completions client method (`client.chat.create(...)`).
  - [ ] Streaming completions returning `AsyncThrowingStream<ChatCompletionChunk, Error>`.
- [ ] **Testing & Verification**
  - [ ] Unit tests using XCTest mock HTTP responses.
  - [ ] Integration tests using real API keys (gated by local env files).

---

## <a name="ag-references"></a>[AG-REFS] 5. Key Reference Files

* **API Specification Reference**: [MIXLAYER.md](file:///Users/danmurrelljr/Dev/mutantsoup/mixl_ios/MIXLAYER.md) — Contains REST endpoints, parameter guides, reasoning models, and tool details.
* **Main Project Readme**: [README.md](file:///Users/danmurrelljr/Dev/mutantsoup/mixl_ios/README.md) — Main human onboarding and build guide.
