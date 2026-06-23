import Foundation

// MARK: - Leaf message components

/// A system instruction message. The declarative analog of `Message.system`.
public struct System: PromptContent {
    let content: String
    let name: String?

    /// Creates a system message.
    public init(_ content: String, name: String? = nil) {
        self.content = content
        self.name = name
    }

    public func build(into resolution: inout PromptResolution) {
        resolution.append(.system(content, name: name))
    }
}

/// A user message. The declarative analog of `Message.user`.
public struct User: PromptContent {
    let content: String
    let name: String?

    /// Creates a user message.
    public init(_ content: String, name: String? = nil) {
        self.content = content
        self.name = name
    }

    public func build(into resolution: inout PromptResolution) {
        resolution.append(.user(content, name: name))
    }
}

/// An assistant message, used to seed prior turns. The declarative analog of `Message.assistant`.
public struct Assistant: PromptContent {
    let content: String
    let reasoningContent: String?

    /// Creates an assistant message.
    public init(_ content: String, reasoning reasoningContent: String? = nil) {
        self.content = content
        self.reasoningContent = reasoningContent
    }

    public func build(into resolution: inout PromptResolution) {
        resolution.append(.assistant(content, reasoningContent: reasoningContent))
    }
}

/// A tool-result message answering a prior tool call. The declarative analog of `Message.tool`.
public struct ToolReply: PromptContent {
    let content: String
    let toolCallId: String

    /// Creates a tool-result message.
    public init(_ content: String, toolCallId: String) {
        self.content = content
        self.toolCallId = toolCallId
    }

    public func build(into resolution: inout PromptResolution) {
        resolution.append(.tool(content, toolCallId: toolCallId))
    }
}

/// A raw `Message` passes straight through, so existing conversation history composes alongside the
/// leaf components (for example `for message in history { message }`).
extension Message: PromptContent {
    public func build(into resolution: inout PromptResolution) {
        resolution.append(self)
    }
}

// MARK: - Container

/// A concrete container of declaratively-composed content.
///
/// `Prompt` is the value you build inline and then modify and run — the analog of composing a
/// SwiftUI view or a Foundation Models `Profile`:
///
/// ```swift
/// let prompt = Prompt {
///     System("You are concise.")
///     User(question)
/// }
/// .temperature(0.5)
/// .reasoning(.high)
///
/// let response = try await client.run(.qwen3_5_27b, prompt)
/// ```
public struct Prompt: PromptContent {
    private let parts: [any PromptContent]

    /// Builds a prompt from composed content.
    public init(@PromptBuilder _ content: () -> [any PromptContent]) {
        self.parts = content()
    }

    public func build(into resolution: inout PromptResolution) {
        for part in parts {
            part.build(into: &resolution)
        }
    }
}

// MARK: - Custom composite components

/// A reusable, parameterized prompt defined by its `body` — the analog of SwiftUI's `View` protocol
/// and Foundation Models' `DynamicInstructions`.
///
/// Conform a type and compose its `body`; the body is re-evaluated each time the prompt runs, so it
/// can branch on current state. Because Mixl is stateless per request, there is no session or
/// transcript to manage — the body simply renders fresh each call.
///
/// ```swift
/// struct SupportPrompt: PromptComponent {
///     var question: String
///     var history: [Message] = []
///
///     var body: some PromptContent {
///         System("You are a concise support agent.")
///         for message in history { message }
///         User(question)
///     }
/// }
///
/// let response = try await client.run(.qwen3_5_27b, SupportPrompt(question: q))
/// ```
public protocol PromptComponent: PromptContent {
    associatedtype Body: PromptContent
    /// The composed content of this prompt, re-evaluated on each run.
    @PromptBuilder var body: Body { get }
}

extension PromptComponent {
    public func build(into resolution: inout PromptResolution) {
        body.build(into: &resolution)
    }
}
