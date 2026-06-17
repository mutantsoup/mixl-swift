# MixLayer API Reference

> [!NOTE]
> This document is optimized for both human developers and AI coding agents. It utilizes specific anchor tags (e.g., `[ML-REF-*]`) to enable rapid semantic and text searches.

---

## [ML-REF-INDEX] Section Index
1. [Endpoint Configuration](#ml-ref-endpoints) — `[ML-REF-ENDPOINTS]`
2. [Model Directory](#ml-ref-models) — `[ML-REF-MODELS]`
3. [Chat Completions API](#ml-ref-chat) — `[ML-REF-CHAT]`
4. [Thinking Mode (Reasoning)](#ml-ref-thinking) — `[ML-REF-THINKING]`
5. [Tool Calling Specs](#ml-ref-tools) — `[ML-REF-TOOLS]`
6. [OpenAI Compatibility](#ml-ref-compat) — `[ML-REF-COMPAT]`
7. [Local Backend (Foundation Models)](#ml-ref-local) — `[ML-REF-LOCAL]`

---

## <a name="ml-ref-endpoints"></a>[ML-REF-ENDPOINTS] 1. Endpoint Configuration

MixLayer exposes a standard OpenAI-compatible REST API.

* **Base URL**: `https://models.mixlayer.ai/v1`
* **Authentication**: HTTP Bearer Auth using the `Authorization: Bearer <API_KEY>` header.
* **Content Type**: `application/json` for requests; responses are returned as `application/json` or `text/event-stream` (when streaming).

---

## <a name="ml-ref-models"></a>[ML-REF-MODELS] 2. Model Directory

Pass the exact **Identifier** string in the `model` parameter of your chat completions request.

| Model Family | Identifier | Context | Features | Best Workload / Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Qwen 3.5 4B (Free)** | `qwen/qwen3.5-4b-free` | 131,072 | Tools, Reasoning | Free tier. Ideal for prototyping. Rate-limited, not for production. |
| **Qwen 3.5 9B** | `qwen/qwen3.5-9b` | 131,072 | Tools, Reasoning | Low cost. High-volume simple chat, classification, summarization. |
| **Qwen 3.5 27B** | `qwen/qwen3.5-27b` | 131,072 | Tools, Reasoning | Strong multi-step reasoning, instruction-following. |
| **Qwen 3.5 35B (MoE)** | `qwen/qwen3.5-35b-a3b` | 131,072 | Tools, Reasoning | Mixture of Experts (3B active). Balanced quality and low latency. |
| **Qwen 3.5 122B (MoE)**| `qwen/qwen3.5-122b-a10b`| 131,072 | Tools, Reasoning | Mixture of Experts (10B active). Complex coding & reasoning tasks. |
| **Qwen 3.5 397B (MoE)**| `qwen/qwen3.5-397b-a17b`| 131,072 | Tools, Reasoning | Mixture of Experts (17B active). Frontier model for agentic loops. |

---

## <a name="ml-ref-chat"></a>[ML-REF-CHAT] 3. Chat Completions API

### HTTP Request
`POST https://models.mixlayer.ai/v1/chat/completions`

### Request Parameters (JSON Body)
* `model` (String, Required): The model identifier (e.g., `qwen/qwen3.5-27b`).
* `messages` (Array, Required): List of message objects representing the conversation.
  * `role` (String, Required): One of `system`, `user`, `assistant`, `tool`.
  * `content` (String, Required/Nullable): The text content of the message.
  * `name` (String, Optional): Participant identifier, required for tool execution results if mapping back.
  * `tool_calls` (Array, Optional): Included when the assistant requests function calls.
  * `tool_call_id` (String, Optional): Required when `role` is `tool`.
* `thinking` (Boolean, Optional): Enable (`true`) or disable (`false`) chain-of-thought reasoning. Default is off when omitted.
* `reasoning_effort` (String, Optional): OpenAI-compatible alias accepting `low`, `medium`, or `high`. Per [MixLayer reasoning docs](https://docs.mixlayer.com/reasoning), distinct levels are reserved for future use. See [Thinking Mode](#ml-ref-thinking).
* `temperature` (Float, Optional): Controls randomness. Range: `0.0` to `2.0`.
* `top_p` (Float, Optional): Nucleus sampling threshold.
* `top_k` (Integer, Optional): Keep only top K tokens.
* `presence_penalty` (Float, Optional): Penalty for repeating topics.
* `repetition_penalty` (Float, Optional): Penalty for repeating exact words.
* `stream` (Boolean, Optional): If `true`, streams SSE tokens (`text/event-stream`).
* `tools` (Array, Optional): A list of functions the model may call.
* `response_format` (Object, Optional): e.g., `{"type": "json_object"}` or `{"type": "json_schema", "json_schema": {...}}`.
* `max_completion_tokens` (Integer, Optional): Maximum tokens to generate. Takes precedence over `max_tokens`.
* `max_tokens` (Integer, Optional): Legacy alias for `max_completion_tokens`.
* `stop` (Array of Strings, Optional): Sequences that halt generation when produced.
* `seed` (Integer, Optional): Best-effort deterministic sampling.
* `frequency_penalty` (Float, Optional): Penalizes tokens proportional to how often they have already appeared. Range: `-2.0` to `2.0`.

### Recommended Sampling Parameter Configurations

| Mode / Task Type | Temperature | Top P | Top K | Repetition Penalty | Presence Penalty |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Thinking: General Tasks** | `1.0` | `0.95` | `20` | `1.0` | `0.0` |
| **Thinking: Coding/Math** | `0.6` | `0.95` | `20` | `1.0` | `0.0` |
| **Instruct (Non-Thinking)** | `0.7` | `0.80` | `20` | `1.0` | `1.5` |

---

## <a name="ml-ref-thinking"></a>[ML-REF-THINKING] 4. Thinking Mode (Reasoning)

MixLayer's Qwen models feature an internal chain-of-thought capability. When enabled, reasoning is returned in a separate `reasoning_content` field on the assistant message (or in `delta.reasoning_content` when streaming). The visible answer remains in `content`.

Canonical upstream reference: [docs.mixlayer.com/reasoning](https://docs.mixlayer.com/reasoning).

### Non-Thinking (Default / Instruct Mode)

Omit both `thinking` and `reasoning_effort` for standard instruct-style responses. The visible answer is in `content`.

Some models may still populate `reasoning_content` on non-streaming responses even without thinking parameters (behavior can vary by model SKU or account tier). Use `thinking: false` to force it off, or ignore `reasoning_content` in your UI if you only want the final answer.

```json
{
  "model": "qwen/qwen3.5-27b",
  "messages": [{"role": "user", "content": "Why is the sky blue?"}],
  "temperature": 0.7
}
```

To explicitly disable thinking on a model that defaults to it, pass `"thinking": false`.

### How to Enable Thinking

| Approach | Example | Mixl API |
| :--- | :--- | :--- |
| MixLayer native | `"thinking": true` | `thinking: true` |
| OpenAI-compatible alias | `"reasoning_effort": "low" \| "medium" \| "high"` | `reasoningEffort: .low` / `.medium` / `.high` |

[MixLayer's reasoning docs](https://docs.mixlayer.com/reasoning) describe `reasoning_effort` as an OpenAI-compatible alias. Officially, distinct `low` / `medium` / `high` levels are **reserved for future use** and currently map to the same boolean enable/disable as `thinking: true`.

When `thinking: true` or `reasoning_effort` is set on supported models, `reasoning_content` typically appears before `content` in streaming responses. Effort-level differences, if any, are model-dependent — verify against your target SKU (free-tier and smaller models may behave differently than larger production models).

```swift
// Explicit full reasoning (recommended):
client.chat.createStream(..., thinking: true)

// OpenAI-compatible alias:
client.chat.createStream(..., reasoningEffort: .medium)
```

> [!IMPORTANT]
> **API Constraint**: Thinking mode is incompatible with JSON schema validation (`response_format: {"type": "json_schema"}`). If structured output is required alongside thinking, use `response_format: {"type": "json_object"}` and prompt the model to write JSON.

### Recommended Sampling (Thinking vs Non-Thinking)

See the [Recommended Sampling Parameter Configurations](#ml-ref-chat) table. Thinking mode typically uses `temperature: 1.0`; instruct (non-thinking) mode often uses `temperature: 0.7`.

### Reading Non-Streaming Responses
If thinking is enabled, the assistant message in the response choice will populate the custom `reasoning_content` field:
```json
{
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "reasoning_content": "Let me calculate 17 * 23. 17 * 20 is 340. 17 * 3 is 51. 340 + 51 = 391.",
      "content": "The answer is 391."
    },
    "finish_reason": "stop"
  }]
}
```

### Reading Streaming Responses
When `stream: true` is configured, reasoning tokens arrive first in `delta.reasoning_content` before the final response starts arriving in `delta.content`.
```json
data: {"choices":[{"delta":{"role":"assistant"}}]}
data: {"choices":[{"delta":{"reasoning_content":"Let me calculate. "}}]}
data: {"choices":[{"delta":{"reasoning_content":"17 * 23 = 391."}}]}
data: {"choices":[{"delta":{"content":"17 * 23 is 391."},"finish_reason":"stop"}]}
```

---

## <a name="ml-ref-tools"></a>[ML-REF-TOOLS] 5. Tool Calling Specs

To enable tool calling, declare functions in the request payload and manage the loop.

### 1. Declaring Tools
```json
{
  "model": "qwen/qwen3.5-27b",
  "messages": [{"role": "user", "content": "What is the weather in Paris?"}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "get_weather",
      "description": "Get the current weather for a city.",
      "parameters": {
        "type": "object",
        "properties": {
          "city": { "type": "string" }
        },
        "required": ["city"]
      },
      "strict": true
    }
  }]
}
```

### 2. Handling the Response
If a tool needs to be called, the API response returns `finish_reason: "tool_calls"`:
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "tool_calls": [{
        "id": "call_abc123",
        "type": "function",
        "function": {
          "name": "get_weather",
          "arguments": "{\"city\":\"Paris\"}"
        }
      }]
    },
    "finish_reason": "tool_calls"
  }]
}
```

### 3. Submitting Tool Results
Submit the output in a follow-up request. You must send back all historical messages, the assistant message that requested the tool call, and a new message with `role: "tool"`.
```json
{
  "model": "qwen/qwen3.5-27b",
  "messages": [
    { "role": "user", "content": "What is the weather in Paris?" },
    {
      "role": "assistant",
      "tool_calls": [{
        "id": "call_abc123",
        "type": "function",
        "function": { "name": "get_weather", "arguments": "{\"city\":\"Paris\"}" }
      }]
    },
    {
      "role": "tool",
      "tool_call_id": "call_abc123",
      "content": "{\"temp_c\": 18, \"condition\": \"cloudy\"}"
    }
  ]
}
```

---

## <a name="ml-ref-compat"></a>[ML-REF-COMPAT] 6. OpenAI Compatibility

MixLayer accepts the OpenAI Chat Completions shape, but not every OpenAI parameter is supported. The canonical upstream reference is [docs.mixlayer.com/chat-completions](https://docs.mixlayer.com/chat-completions).

### Supported by Mixl

| Parameter | Mixl Property |
| :--- | :--- |
| `model` | `Model` / `ChatCompletionRequest.model` |
| `messages` | `[Message]` |
| `thinking` | `thinking` |
| `reasoning_effort` | `reasoningEffort` (`ReasoningEffort`) |
| `temperature`, `top_p`, `top_k` | `temperature`, `topP`, `topK` |
| `frequency_penalty`, `presence_penalty`, `repetition_penalty` | `frequencyPenalty`, `presencePenalty`, `repetitionPenalty` |
| `max_completion_tokens`, `max_tokens` | `maxCompletionTokens`, `maxTokens` |
| `stop`, `seed`, `stream` | `stop`, `seed`, `stream` |
| `tools` | `tools` |
| `response_format` | `responseFormat` (`.text`, `.jsonObject`, `.jsonSchema`) |

### Not Supported by MixLayer (omit from Mixl)

These OpenAI parameters are accepted by some gateways but are **silently ignored** by MixLayer. Mixl intentionally does not expose them:

- `tool_choice` — the model decides whether to call a tool based on `tools` and the conversation. Prompt explicitly if you need to force a tool.
- `n` — multiple completions per request
- `min_p` — minimum probability sampling
- `logprobs`, `top_logprobs`
- `user`
- `logit_bias`

### Error Envelope

MixLayer returns OpenAI-style errors:

```json
{
  "error": {
    "message": "Model not found.",
    "type": "model_not_found",
    "code": "model_not_found"
  }
}
```

Mixl surfaces these as `MixlError.httpError(statusCode:apiError:)`.

---

## <a name="ml-ref-local"></a>[ML-REF-LOCAL] 7. Local Backend (Foundation Models)

Mixl’s **`LocalClient`** runs chat completions on-device via Apple’s **Foundation Models** framework (`LanguageModelSession` / `SystemLanguageModel`). It uses the same `chat.create` / `chat.createStream` API shape as **`MixLayerClient`**, but does not require a MixLayer API key.

### Requirements

| Requirement | Details |
| :--- | :--- |
| **OS** | iOS 26+, macOS 26+, visionOS 26+, watchOS 26+, tvOS 26+ (`@available` on `LocalClient`) |
| **Framework** | `FoundationModels` (Xcode 26 SDK). CI builds without the framework use a stub backend that throws `localModelUnavailable(.frameworkNotAvailable)`. |
| **Device** | Apple Intelligence-capable hardware with on-device model assets downloaded |
| **Model identifier** | `apple/foundation` (`Model.appleFoundation`) |

Check availability before calling inference:

```swift
if let reason = LocalModelSupport.unavailabilityReason() {
    // Show UI: LocalModelSupport.message(for: reason)
}
```

### Error Semantics

| Error | Meaning |
| :--- | :--- |
| `MixlError.modelNotSupported(model:backend:)` | Wrong model for this client (e.g. cloud Qwen model passed to `LocalClient`). |
| `MixlError.localModelUnavailable(reason:message:)` | Correct model/client, but the device or OS cannot run on-device inference (ineligible device, Apple Intelligence off, model not ready, framework missing). |
| `MixlError.unsupportedParameter(_:)` | Semantic mismatch on local path: `tools`, JSON `response_format`, or tool messages. Sampling/reasoning params are stripped with an `os.Logger` message instead. |
| `MixlError.localInferenceFailed(_:)` | Inference failed after availability checks passed. |

### Parameter Compatibility (Local vs Cloud)

| Parameter | MixLayer Cloud | Local (`LocalClient`) |
| :--- | :---: | :---: |
| `messages` | ✅ | ✅ (system / user / assistant only; tool messages **strict**) |
| `temperature` | ✅ | ✅ |
| `maxCompletionTokens` / `maxTokens` | ✅ | ✅ (maps to `maximumResponseTokens`) |
| `stream` | ✅ | ✅ (`createStream`) |
| `thinking` / `reasoningEffort` | ✅ | stripped (logged) |
| `top_p`, `top_k`, penalties, `stop`, `seed` | ✅ | stripped (logged) |
| `tools` / tool messages | ✅ | **strict** (throws) |
| `responseFormat` (JSON) | ✅ | **strict** (throws; text only) |

### Design Notes

- **Stateless:** Each request creates a new `LanguageModelSession` (no conversation persistence in Mixl).
- **Streaming:** Local streaming uses Foundation Models `streamResponse`; Mixl emits OpenAI-style `ChatCompletionChunk` deltas.
- A future orchestrator will route by `Model.provider` to `MixLayerClient` or `LocalClient`.
