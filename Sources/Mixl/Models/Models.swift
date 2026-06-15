import Foundation

/// A type representing a MixLayer model name.
///
/// Use predefined static properties (like `.qwen3_5_9b`) or construct a custom model using `.custom("identifier")`.
public struct Model: RawRepresentable, Codable, Sendable, Equatable, Hashable {
    /// The raw string identifier of the model.
    public let rawValue: String

    /// Initializes a model with a raw string identifier.
    ///
    /// - Parameter rawValue: The model's identifier string.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Qwen 3.5 4B (Free Tier) model.
    public static let qwen3_5_4b_free = Model(rawValue: "qwen/qwen3.5-4b-free")
    
    /// Qwen 3.5 9B model.
    public static let qwen3_5_9b = Model(rawValue: "qwen/qwen3.5-9b")
    
    /// Qwen 3.5 27B model.
    public static let qwen3_5_27b = Model(rawValue: "qwen/qwen3.5-27b")
    
    /// Qwen 3.5 35B Mixture of Experts model.
    public static let qwen3_5_35b_a3b = Model(rawValue: "qwen/qwen3.5-35b-a3b")
    
    /// Qwen 3.5 122B Mixture of Experts model.
    public static let qwen3_5_122b_a10b = Model(rawValue: "qwen/qwen3.5-122b-a10b")
    
    /// Qwen 3.5 397B Mixture of Experts model.
    public static let qwen3_5_397b_a17b = Model(rawValue: "qwen/qwen3.5-397b-a17b")

    /// Initializes a custom model identifier that is not yet predefined.
    ///
    /// - Parameter name: The custom identifier string of the model.
    /// - Returns: A configured `Model` instance.
    public static func custom(_ name: String) -> Model {
        Model(rawValue: name)
    }

    /// Decodes a model from a single-value container containing a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    /// Encodes a model to a single-value container as a string.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The role of a message author in a chat completion conversation.
public enum Role: String, Codable, Sendable {
    /// System instruction guidelines.
    case system
    /// User prompt input.
    case user
    /// Assistant model response.
    case assistant
    /// Return value of a tool/function call execution.
    case tool
}

/// A structure representing a chat completion message.
public struct Message: Codable, Sendable, Equatable {
    /// The role of the message author.
    public let role: Role
    
    /// The text content of the message.
    public let content: String?
    
    /// The intermediate thinking/reasoning chain content of the assistant message, if any.
    public let reasoningContent: String?
    
    /// The optional name of the message participant.
    public let name: String?
    
    /// The tool calls requested by the model (for assistant messages).
    public let toolCalls: [ToolCall]?
    
    /// The tool call ID that this message is responding to (for tool messages).
    public let toolCallId: String?

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
        case name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    /// Initializes a new chat completion message.
    ///
    /// - Parameters:
    ///   - role: The role of the author.
    ///   - content: The content string.
    ///   - reasoningContent: The chain-of-thought reasoning content.
    ///   - name: The participant name.
    ///   - toolCalls: The tool calls requested by the model.
    ///   - toolCallId: The tool call ID that this message is responding to.
    public init(
        role: Role,
        content: String? = nil,
        reasoningContent: String? = nil,
        name: String? = nil,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    /// Creates a system instruction message.
    public static func system(_ content: String, name: String? = nil) -> Message {
        Message(role: .system, content: content, name: name)
    }

    /// Creates a user input message.
    public static func user(_ content: String, name: String? = nil) -> Message {
        Message(role: .user, content: content, name: name)
    }

    /// Creates an assistant response message.
    public static func assistant(_ content: String, reasoningContent: String? = nil, toolCalls: [ToolCall]? = nil) -> Message {
        Message(role: .assistant, content: content, reasoningContent: reasoningContent, toolCalls: toolCalls)
    }

    /// Creates a tool execution result message.
    public static func tool(_ content: String, toolCallId: String) -> Message {
        Message(role: .tool, content: content, toolCallId: toolCallId)
    }
}

/// A structure representing a tool call requested by the model.
public struct ToolCall: Codable, Sendable, Equatable {
    /// The unique identifier of the tool call.
    public let id: String
    
    /// The type of the tool. Defaults to `"function"`.
    public let type: String
    
    /// The function details, including name and arguments.
    public let function: FunctionCall

    /// Initializes a new tool call request.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the tool call.
    ///   - type: The type of the tool. Defaults to `"function"`.
    ///   - function: The function details, including name and arguments.
    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// A structure representing a function execution request.
public struct FunctionCall: Codable, Sendable, Equatable {
    /// The name of the function to call.
    public let name: String
    
    /// The JSON string containing the arguments to pass.
    public let arguments: String

    /// Initializes a new function execution request.
    ///
    /// - Parameters:
    ///   - name: The name of the function to call.
    ///   - arguments: The JSON string containing the arguments to pass.
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }

    /// Decodes the JSON-formatted arguments string into a custom `Decodable` type.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` target type.
    ///   - decoder: The `JSONDecoder` instance to use.
    /// - Returns: A decoded instance of the target type.
    /// - Throws: An error if the arguments cannot be parsed.
    public func decodeArguments<T: Decodable>(as type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let data = arguments.data(using: .utf8) else {
            throw NSError(
                domain: "FunctionCall",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert arguments string to UTF-8 data"]
            )
        }
        return try decoder.decode(T.self, from: data)
    }
}
