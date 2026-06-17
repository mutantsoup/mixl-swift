import Foundation

/// Maps Mixl ``Message`` arrays into Foundation Models session inputs.
///
/// ``LocalPromptBuilder`` is a namespace (caseless `enum`) used internally by
/// ``LocalInferenceService``. It performs a **stateless** transform on each request: system
/// messages become `LanguageModelSession` instructions; user and assistant turns are formatted
/// into a single conversation string passed to `respond(to:)` / `streamResponse(to:)`.
///
/// ## Overview
///
/// Mixl's local backend does not persist conversation state between calls. Every
/// ``LocalClient`` request must include the full message history you want the model to see.
/// This builder converts that history into the shape Apple's Foundation Models API expects.
///
/// The type is implemented as a caseless `enum` so it cannot be instantiated — only the static
/// ``build(from:)`` entry point is used. Nested ``BuiltPrompt`` and ``Error`` types keep the
/// mapping logic and its failure modes in one place for unit testing via `@testable import Mixl`.
///
/// ## Mapping rules
///
/// | ``Message`` role | Destination |
/// | --- | --- |
/// | ``Role/system`` | Combined into ``BuiltPrompt/instructions`` (joined with blank lines) |
/// | ``Role/user`` | `"User: …"` line in ``BuiltPrompt/prompt`` |
/// | ``Role/assistant`` | `"Assistant: …"` line in ``BuiltPrompt/prompt`` |
/// | ``Role/tool`` | Rejected — throws ``Error/unsupportedToolMessages`` |
/// | Messages with `toolCalls` | Rejected — throws ``Error/unsupportedToolMessages`` |
///
/// Empty or whitespace-only message content is skipped. If no non-empty user content remains
/// after filtering, ``Error/missingUserMessage`` is thrown.
///
/// ## Example
///
/// ```swift
/// let built = try LocalPromptBuilder.build(from: [
///     .system("You are helpful."),
///     .user("Hello"),
///     .assistant("Hi there."),
///     .user("What is Mixl?")
/// ])
/// // built.instructions == "You are helpful."
/// // built.prompt == "User: Hello\nAssistant: Hi there.\nUser: What is Mixl?"
/// ```
///
/// ``LocalInferenceService`` passes `built.instructions` to `LanguageModelSession(instructions:)`
/// and `built.prompt` as the user turn for inference.
///
/// ## Error mapping
///
/// ``LocalInferenceService`` translates builder errors into public ``MixlError`` values:
///
/// | ``Error`` | ``MixlError`` |
/// | --- | --- |
/// | ``unsupportedToolMessages`` | ``unsupportedParameter("tool messages")`` |
/// | ``emptyMessages`` | ``decodingFailed("messages must not be empty")`` |
/// | ``missingUserMessage`` | ``decodingFailed("messages must include at least one user message")`` |
enum LocalPromptBuilder {
    /// The Foundation Models inputs produced by ``build(from:)``.
    struct BuiltPrompt: Equatable, Sendable {
        /// System instructions for `LanguageModelSession`, or `nil` when no system messages were provided.
        ///
        /// When non-`nil`, ``LocalInferenceService`` creates the session with
        /// `LanguageModelSession(instructions:)`. When `nil`, it uses the default session.
        let instructions: String?

        /// The formatted conversation string passed to `respond(to:)` / `streamResponse(to:)`.
        ///
        /// Contains labeled user and assistant lines joined by newlines, for example:
        /// `"User: Hello\nAssistant: Hi there.\nUser: What is Mixl?"`.
        let prompt: String
    }

    /// Errors thrown while converting ``Message`` values into a ``BuiltPrompt``.
    enum Error: Swift.Error, Equatable {
        /// The input array was empty.
        case emptyMessages

        /// The history includes tool results or assistant messages with `toolCalls`.
        ///
        /// Tool calling is not supported on the local Foundation Models path.
        case unsupportedToolMessages

        /// No user message with non-empty content was found.
        ///
        /// Thrown when the array is system-only, user-only with blank content, or otherwise
        /// produces no prompt lines.
        case missingUserMessage
    }

    /// Converts a Mixl message history into Foundation Models session instructions and a prompt string.
    ///
    /// - Parameter messages: The full conversation history for a single stateless inference request.
    /// - Returns: A ``BuiltPrompt`` ready for ``LocalInferenceService`` to pass to
    ///   `LanguageModelSession`.
    /// - Throws: ``Error`` when the history cannot be mapped (see ``Error``).
    static func build(from messages: [Message]) throws -> BuiltPrompt {
        guard !messages.isEmpty else {
            throw Error.emptyMessages
        }

        if messages.contains(where: { $0.role == .tool || $0.toolCalls != nil }) {
            throw Error.unsupportedToolMessages
        }

        let systemInstructions = messages
            .filter { $0.role == .system }
            .compactMap(\.content)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let conversationMessages = messages.filter { $0.role != .system }
        guard conversationMessages.contains(where: { $0.role == .user }) else {
            throw Error.missingUserMessage
        }

        var lines: [String] = []
        for message in conversationMessages {
            guard let content = message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                continue
            }

            switch message.role {
            case .user:
                lines.append("User: \(content)")
            case .assistant:
                lines.append("Assistant: \(content)")
            case .system, .tool:
                break
            }
        }

        guard !lines.isEmpty else {
            throw Error.missingUserMessage
        }

        return BuiltPrompt(
            instructions: systemInstructions.isEmpty ? nil : systemInstructions,
            prompt: lines.joined(separator: "\n")
        )
    }
}
