# Composing prompts declaratively

Build chat completions with a SwiftUI-style declarative API — composed content, chainable modifiers, and custom components — layered over the existing ``MixlClient``.

## Overview

The declarative layer is **pure syntactic sugar**. Composed ``PromptContent`` resolves to a `ChatCompletionRequest` (plus an optional per-prompt router and transform chain) and runs through the same pipeline as the imperative `chat.create` / `chat.createStream` API, which is unchanged. Use whichever style fits the call.

The design mirrors SwiftUI and Apple's Foundation Models profiles: leaf components compose in a `@PromptBuilder`, modifiers chain like view modifiers, and reusable prompts are defined by a `body`.

```swift
import Mixl

let client = MixlClient(apiKey: "your-api-key")

let response = try await client.run(.qwen3_5_27b) {
    System("You are concise.")
    User("Explain routing in one sentence.")
}
```

Because the layer compiles down to the orchestrator, **every Mixl feature is reachable**: model selection, messages, thinking/reasoning, all sampling parameters, tools, response format, routing, transforms, and streaming.

## Composing content

Leaf components — ``System``, ``User``, ``Assistant``, and ``ToolReply`` — compose with the ``PromptBuilder`` result builder, which supports `if`, `switch`, and `for`. Raw `Message` values pass straight through, so existing history composes alongside the leaves:

```swift
let history: [Message] = loadHistory()

let response = try await client.run(.qwen3_5_27b) {
    System("You are a support agent.")
    for message in history { message }
    if escalated { System("Escalate politely.") }
    User(question)
}
```

For streaming, use ``MixlClient/stream(_:_:)``:

```swift
for try await chunk in try await client.stream(.qwen3_5_27b, { User(question) }.reasoning(.high)) {
    // handle delta
}
```

## Modifiers

Configure a prompt with chainable modifiers — the analog of SwiftUI view modifiers and Foundation Models' `Profile` modifiers. They cover the full request surface: ``PromptContent/model(_:)``, ``PromptContent/temperature(_:)``, ``PromptContent/topP(_:)``, ``PromptContent/topK(_:)``, the penalties, ``PromptContent/thinking(_:)``, ``PromptContent/reasoning(_:)``, ``PromptContent/maxCompletionTokens(_:)``, ``PromptContent/maxTokens(_:)``, ``PromptContent/stop(_:)-(String...)``, ``PromptContent/seed(_:)``, and ``PromptContent/responseFormat(_:)``.

```swift
let prompt = Prompt {
    System("You are concise.")
    User(question)
}
.model(deepDive ? .qwen3_5_27b : .qwen3_5_4b_free)
.temperature(0.5)
.reasoning(.high)
.maxCompletionTokens(800)

let response = try await client.run(.qwen3_5_27b, prompt)
```

### Precedence

Configuration resolves the way Apple's profiles do: the **innermost** modifier wins (each field is filled only if not already set), and the `baseModel` passed to `run` / `stream` is the lowest-priority default that a ``PromptContent/model(_:)`` modifier overrides.

## Tools

Declare function tools with the ``ToolBuilder`` DSL and ``FunctionTool(_:_:fields:)``, building the JSON Schema from ``Field`` values:

```swift
let prompt = Prompt { User("What time is it in Tokyo?") }
    .tools {
        FunctionTool("get_time", "Get the current time for a city") {
            Field("city", .string, "City name", required: true)
        }
    }
```

## Routing and transforms

The routing and transform features from the orchestrator are exposed as modifiers, so a prompt can carry its own policy. A per-prompt ``PromptContent/router(_:)`` overrides the client's router for that call; per-prompt transforms run after the client's configured transforms.

```swift
let prompt = Prompt { User(transcribed) }
    .mapContent { $0.replacingOccurrences(of: "Project Cerberus", with: "[REDACTED]") }  // → MixlRequestTransform
    .fallback(to: .qwen3_5_4b_free)                                                      // → MixlFallbackRouter
```

## Reusable components

Define a reusable, parameterized prompt by conforming to ``PromptComponent`` and composing its `body` — the analog of SwiftUI's `View` and Foundation Models' `DynamicInstructions`. The body is re-evaluated on each run, so it can branch on current state:

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

let response = try await client.run(.qwen3_5_27b, SupportPrompt(question: question))
```

## Custom modifiers

Package reusable behavior as a ``PromptModifier`` — the analog of `ViewModifier` and Foundation Models' `DynamicProfileModifier`:

```swift
struct Redacting: PromptModifier {
    let term: String
    func body(content: AnyPromptContent) -> some PromptContent {
        content.mapContent { $0.replacingOccurrences(of: term, with: "[REDACTED]") }
    }
}

extension PromptContent {
    func redact(_ term: String) -> some PromptContent { modifier(Redacting(term: term)) }
}

// usage
try await client.run(.qwen3_5_27b, Prompt { User(text) }.redact("Project Cerberus"))
```

## Chaining requests across models

Each `run` is a single request, so chaining is ordinary `async`/`await` sequencing — run one prompt, then feed its output into the next, which can target a different model. The declarative builder makes composing the follow-up clean, since the prior response drops straight in as an `Assistant` turn:

```swift
let question = "How should a mobile app choose between on-device and cloud inference?"

// Draft on a fast model (here, on-device).
let draft = try await client.run(.appleFoundation) {
    System("Draft a brief answer in plain prose.")
    User(question)
}
let draftText = draft.choices.first?.message.content ?? ""

// Refine on a different model, feeding the draft back in.
let refined = try await client.run(.qwen3_5_27b) {
    System("You are an editor. Improve the draft. Return only the improved answer.")
    User(question)
    Assistant(draftText)
    User("Refine the draft above.")
}
```

Because ``MixlClient`` routes per request, the two steps can run on different backends — for example an on-device draft refined in the cloud — without any extra wiring.

## Relationship to sessions

Mixl is stateless per request, so the declarative layer deliberately stops at *describing a request*. It does not model a stateful session or transcript — there is no shared session state, no lifecycle/transition hooks, and no history management. The closest stateless analog to history transformation is a ``MixlRequestTransform``, available here as ``PromptContent/mapContent(_:)`` and ``PromptContent/transform(_:)-(MixlRequestTransform)``.

## Topics

### Composing

- ``PromptContent``
- ``PromptBuilder``
- ``System``
- ``User``
- ``Assistant``
- ``ToolReply``
- ``Prompt``

### Running

- ``MixlClient/run(_:_:)``
- ``MixlClient/stream(_:_:)``

### Previewing

- ``PromptContent/resolvedMessages()``
- ``PromptContent/resolvedTools()``

### Reusable components and modifiers

- ``PromptComponent``
- ``PromptModifier``
- ``AnyPromptContent``

### Tools

- ``FunctionTool(_:_:fields:)``
- ``Field``
- ``ToolBuilder``
- ``FieldBuilder``
