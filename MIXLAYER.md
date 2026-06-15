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
* `thinking` (Boolean, Optional): Enable/disable chain-of-thought reasoning. Default is `false`.
* `reasoning_effort` (String, Optional): OpenAI alias for thinking. Accepts `low`, `medium`, `high`. Maps to a boolean enable/disable under the hood.
* `temperature` (Float, Optional): Controls randomness. Range: `0.0` to `2.0`.
* `top_p` (Float, Optional): Nucleus sampling threshold.
* `top_k` (Integer, Optional): Keep only top K tokens.
* `presence_penalty` (Float, Optional): Penalty for repeating topics.
* `repetition_penalty` (Float, Optional): Penalty for repeating exact words.
* `stream` (Boolean, Optional): If `true`, streams SSE tokens (`text/event-stream`).
* `tools` (Array, Optional): A list of functions the model may call.
* `response_format` (Object, Optional): e.g., `{"type": "json_object"}`.

### Recommended Sampling Parameter Configurations

| Mode / Task Type | Temperature | Top P | Top K | Repetition Penalty | Presence Penalty |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Thinking: General Tasks** | `1.0` | `0.95` | `20` | `1.0` | `0.0` |
| **Thinking: Coding/Math** | `0.6` | `0.95` | `20` | `1.0` | `0.0` |
| **Instruct (Non-Thinking)** | `0.7` | `0.80` | `20` | `1.0` | `1.5` |

---

## <a name="ml-ref-thinking"></a>[ML-REF-THINKING] 4. Thinking Mode (Reasoning)

MixLayer's Qwen models feature an internal chain-of-thought capability.

### How to Toggle Thinking
Enable thinking by passing `"thinking": true` (or `"reasoning_effort": "medium"`). To explicitly turn off thinking, pass `"thinking": false`.

> [!IMPORTANT]
> **API Constraint**: Thinking mode is incompatible with JSON schema validation (`response_format: {"type": "json_schema"}`). If structured output is required alongside thinking, use `response_format: {"type": "json_object"}` and prompt the model to write JSON.

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
