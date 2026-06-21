import Foundation

/// OpenAI-compatible alias for extended chain-of-thought reasoning.
///
/// MixLayer accepts `low`, `medium`, and `high`. Per [MixLayer's reasoning docs](https://docs.mixlayer.com/reasoning),
/// distinct effort levels are reserved for future use and currently map to a boolean enable/disable.
/// Streaming behavior may still vary by model SKU or tier — verify with the model you deploy.
public enum ReasoningEffort: String, Codable, Sendable {
    /// OpenAI-compatible effort alias (`reasoning_effort: "low"`).
    case low
    /// OpenAI-compatible effort alias (`reasoning_effort: "medium"`).
    case medium
    /// OpenAI-compatible effort alias (`reasoning_effort: "high"`).
    case high
}

/// A structure representing a chat completion request payload.
///
/// Shared by ``MixLayerClient`` and ``LocalClient``. Parameter support varies by backend—see
/// <doc:LocalInference> and `MIXLAYER.md`.
public struct ChatCompletionRequest: Codable, Sendable, Equatable {
    /// The model name string identifier.
    public let model: String
    
    /// The list of conversation history messages.
    public let messages: [Message]
    
    /// Enable or disable chain-of-thought reasoning (`thinking: true` / `thinking: false`).
    public let thinking: Bool?
    
    /// OpenAI-compatible alias for enabling thinking (`reasoning_effort`: `low`, `medium`, or `high`).
    ///
    /// Per MixLayer docs, effort levels are reserved for future use. Behavior may vary by model.
    public let reasoningEffort: ReasoningEffort?

    /// Temperature sampling value controlling randomness. Range: 0.0 to 2.0.
    public let temperature: Double?

    /// Nucleus sampling threshold.
    public let topP: Double?

    /// Keep only top K tokens.
    public let topK: Int?

    /// Penalizes tokens proportional to how often they have already appeared.
    public let frequencyPenalty: Double?

    /// Penalty for repeating topics.
    public let presencePenalty: Double?

    /// Penalty for repeating exact words.
    public let repetitionPenalty: Double?

    /// Maximum tokens to generate. Takes precedence over `maxTokens` when both are set.
    public let maxCompletionTokens: Int?

    /// Legacy alias for `maxCompletionTokens`.
    public let maxTokens: Int?

    /// Sequences that halt generation when produced.
    public let stop: [String]?

    /// Best-effort deterministic sampling seed.
    public let seed: Int?
    
    /// Enable streaming output as Server-Sent Events (SSE).
    public let stream: Bool?
    
    /// The function tools that the model can call.
    public let tools: [Tool]?
    
    /// The desired structure output formatting configuration.
    public let responseFormat: ResponseFormat?

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case thinking
        case reasoningEffort = "reasoning_effort"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case repetitionPenalty = "repetition_penalty"
        case maxCompletionTokens = "max_completion_tokens"
        case maxTokens = "max_tokens"
        case stop
        case seed
        case stream
        case tools
        case responseFormat = "response_format"
    }

    /// Initializes a new Chat Completion Request.
    ///
    /// - Parameters:
    ///   - model: The model name string identifier.
    ///   - messages: The list of conversation history messages.
    ///   - thinking: Enable or disable chain-of-thought reasoning (thinking mode).
    ///   - reasoningEffort: Specific effort level for thinking.
    ///   - temperature: Temperature sampling value controlling randomness. Range: 0.0 to 2.0.
    ///   - topP: Nucleus sampling threshold.
    ///   - topK: Keep only top K tokens.
    ///   - frequencyPenalty: Penalizes tokens proportional to how often they have already appeared.
    ///   - presencePenalty: Penalty for repeating topics.
    ///   - repetitionPenalty: Penalty for repeating exact words.
    ///   - maxCompletionTokens: Maximum tokens to generate.
    ///   - maxTokens: Legacy alias for `maxCompletionTokens`.
    ///   - stop: Sequences that halt generation when produced.
    ///   - seed: Best-effort deterministic sampling seed.
    ///   - stream: Enable streaming output as Server-Sent Events (SSE).
    ///   - tools: The function tools that the model can call.
    ///   - responseFormat: The desired structure output formatting configuration.
    public init(
        model: String,
        messages: [Message],
        thinking: Bool? = nil,
        reasoningEffort: ReasoningEffort? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        repetitionPenalty: Double? = nil,
        maxCompletionTokens: Int? = nil,
        maxTokens: Int? = nil,
        stop: [String]? = nil,
        seed: Int? = nil,
        stream: Bool? = nil,
        tools: [Tool]? = nil,
        responseFormat: ResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.thinking = thinking
        self.reasoningEffort = reasoningEffort
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.repetitionPenalty = repetitionPenalty
        self.maxCompletionTokens = maxCompletionTokens
        self.maxTokens = maxTokens
        self.stop = stop
        self.seed = seed
        self.stream = stream
        self.tools = tools
        self.responseFormat = responseFormat
    }
}

extension ChatCompletionRequest {
    /// Helper to create a copy of the request with a different model identifier.
    public func copy(withModel newModel: String) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: newModel,
            messages: messages,
            thinking: thinking,
            reasoningEffort: reasoningEffort,
            temperature: temperature,
            topP: topP,
            topK: topK,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            repetitionPenalty: repetitionPenalty,
            maxCompletionTokens: maxCompletionTokens,
            maxTokens: maxTokens,
            stop: stop,
            seed: seed,
            stream: stream,
            tools: tools,
            responseFormat: responseFormat
        )
    }
}

/// A structure representing a tool the model can invoke.
public struct Tool: Codable, Sendable, Equatable {
    /// The type of the tool. Defaults to `"function"`.
    public let type: String
    
    /// The function definition detail schema.
    public let function: FunctionDefinition

    /// Initializes a new tool specification.
    ///
    /// - Parameters:
    ///   - type: The type of the tool. Defaults to `"function"`.
    ///   - function: The function definition detail schema.
    public init(type: String = "function", function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// A structure representing a function definition parameters and strict schema check rules.
public struct FunctionDefinition: Codable, Sendable, Equatable {
    /// The name of the function.
    public let name: String
    
    /// A description explaining the purpose of the function.
    public let description: String?
    
    /// The parameter JSON schema describing parameters the function accepts.
    public let parameters: JSONSchema?
    
    /// Enable strict schema validation (defaults to `true`).
    public let strict: Bool?

    /// Initializes a new function definition.
    ///
    /// - Parameters:
    ///   - name: The name of the function.
    ///   - description: A description explaining the purpose of the function.
    ///   - parameters: The parameter JSON schema describing parameters the function accepts.
    ///   - strict: Enable strict schema validation (defaults to `true`).
    public init(name: String, description: String? = nil, parameters: JSONSchema? = nil, strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
}

/// Supported JSON Schema type identifiers.
public enum JSONType: String, Codable, Sendable {
    /// A text string.
    case string
    /// A decimal number.
    case number
    /// An integer.
    case integer
    /// A boolean true/false value.
    case boolean
    /// A nested object block containing key-value pairs.
    case object
    /// A list array container.
    case array
    /// A null value.
    case null
}

/// A structure representing a JSON Schema specification for function calling tools.
public struct JSONSchema: Codable, Sendable, Equatable {
    /// The JSON type.
    public let type: JSONType
    
    /// An explanation of the parameter field purpose.
    public let description: String?
    
    /// Child schema properties for nested object types.
    public let properties: [String: JSONSchema]?
    
    /// The list of required properties keys.
    public let required: [String]?
    
    /// The recursive schema items type configuration (for arrays).
    public let items: Box<JSONSchema>?
    
    /// Predefined literal enum choices for the value.
    public let enumValues: [String]?

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case required
        case items
        case enumValues = "enum"
    }

    /// Initializes a new JSON schema configuration.
    ///
    /// - Parameters:
    ///   - type: The JSON type.
    ///   - description: An explanation of the parameter field purpose.
    ///   - properties: Child schema properties for nested object types.
    ///   - required: The list of required properties keys.
    ///   - items: The recursive schema items type configuration (for arrays).
    ///   - enumValues: Predefined literal enum choices for the value.
    public init(
        type: JSONType,
        description: String? = nil,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        items: JSONSchema? = nil,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.properties = properties
        self.required = required
        self.items = items.map { Box($0) }
        self.enumValues = enumValues
    }
}

/// An indirect reference wrapper to support recursive types (such as nested arrays or objects).
public final class Box<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    /// The wrapped value.
    public let value: T

    /// Initializes a box with the wrapped value.
    ///
    /// - Parameter value: The value to wrap inside the box.
    public init(_ value: T) {
        self.value = value
    }

    /// Decodes the value from a single-value container.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(T.self)
    }

    /// Encodes the value into a single-value container.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    /// Performs equality comparison on the wrapped value.
    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
        lhs.value == rhs.value
    }
}

/// Supported response format types.
public enum ResponseFormatType: String, Codable, Sendable {
    /// No output constraint.
    case text
    /// Output must be a syntactically valid JSON object.
    case jsonObject = "json_object"
    /// Output must conform to a supplied JSON Schema.
    case jsonSchema = "json_schema"
}

/// JSON Schema configuration for `json_schema` response formats.
public struct JSONSchemaResponseFormat: Codable, Sendable, Equatable {
    /// The JSON Schema the model output must satisfy.
    public let schema: JSONSchema

    /// Whether strict schema validation is enabled.
    public let strict: Bool?

    /// Initializes a JSON schema response format configuration.
    public init(schema: JSONSchema, strict: Bool? = true) {
        self.schema = schema
        self.strict = strict
    }
}

/// A structure representing the format of the response from the model.
public struct ResponseFormat: Codable, Sendable, Equatable {
    /// The response format type.
    public let type: ResponseFormatType

    /// The JSON Schema configuration when `type` is `.jsonSchema`.
    public let jsonSchema: JSONSchemaResponseFormat?

    private enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    /// Creates a plain text response format.
    public static func text() -> ResponseFormat {
        ResponseFormat(type: .text, jsonSchema: nil)
    }

    /// Creates a JSON object response format.
    public static func jsonObject() -> ResponseFormat {
        ResponseFormat(type: .jsonObject, jsonSchema: nil)
    }

    /// Creates a JSON schema constrained response format.
    public static func jsonSchema(_ schema: JSONSchema, strict: Bool = true) -> ResponseFormat {
        ResponseFormat(type: .jsonSchema, jsonSchema: .init(schema: schema, strict: strict))
    }

    /// Initializes a response format.
    public init(type: ResponseFormatType, jsonSchema: JSONSchemaResponseFormat? = nil) {
        self.type = type
        self.jsonSchema = jsonSchema
    }
}

/// A structure representing the non-streaming chat completion response.
public struct ChatCompletionResponse: Codable, Sendable, Equatable {
    /// The unique identifier of the completion.
    public let id: String
    
    /// The response object type identifier (e.g. `"chat.completion"`).
    public let object: String
    
    /// The creation epoch timestamp.
    public let created: Int
    
    /// The model string identifier that processed this response.
    public let model: String
    
    /// The list of choices returned by the model.
    public let choices: [Choice]
    
    /// The usage metadata summary.
    public let usage: Usage?

    /// A structure representing a single completion choice.
    public struct Choice: Codable, Sendable, Equatable {
        /// The index of the choice.
        public let index: Int
        
        /// The generated message.
        public let message: Message
        
        /// The reason the model finished generating text (e.g. `"stop"`, `"tool_calls"`, etc.).
        public let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }

        /// Initializes a choice.
        ///
        /// - Parameters:
        ///   - index: The index of the choice.
        ///   - message: The generated message.
        ///   - finishReason: The reason the model finished generating text.
        public init(index: Int, message: Message, finishReason: String? = nil) {
            self.index = index
            self.message = message
            self.finishReason = finishReason
        }
    }

    /// A structure representing the token usage metadata for the request.
    public struct Usage: Codable, Sendable, Equatable {
        /// The number of tokens in the prompt.
        public let promptTokens: Int
        
        /// The number of tokens in the generated completion.
        public let completionTokens: Int
        
        /// The total number of tokens processed.
        public let totalTokens: Int

        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }

        /// Initializes a usage metadata instance.
        ///
        /// - Parameters:
        ///   - promptTokens: The number of tokens in the prompt.
        ///   - completionTokens: The number of tokens in the generated completion.
        ///   - totalTokens: The total number of tokens processed.
        public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }
    }
}

/// A structure representing a single streamed chunk of a chat completion response.
public struct ChatCompletionChunk: Codable, Sendable, Equatable {
    /// The unique identifier of the completion.
    public let id: String
    
    /// The response object type identifier (e.g. `"chat.completion.chunk"`).
    public let object: String
    
    /// The creation epoch timestamp.
    public let created: Int
    
    /// The model string identifier.
    public let model: String
    
    /// The choices returned in this chunk.
    public let choices: [ChoiceChunk]

    /// A structure representing a single choice delta chunk.
    public struct ChoiceChunk: Codable, Sendable, Equatable {
        /// The index of the choice.
        public let index: Int
        
        /// The delta representing updates to the message.
        public let delta: ChoiceDelta
        
        /// The optional finish reason if generation ended on this chunk.
        public let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }

        /// Initializes a choice chunk.
        ///
        /// - Parameters:
        ///   - index: The index of the choice.
        ///   - delta: The delta representing updates to the message.
        ///   - finishReason: The optional finish reason if generation ended on this chunk.
        public init(index: Int, delta: ChoiceDelta, finishReason: String? = nil) {
            self.index = index
            self.delta = delta
            self.finishReason = finishReason
        }
    }
}

/// Incremental function call data streamed in a completion chunk.
public struct FunctionCallDelta: Codable, Sendable, Equatable {
    /// The function name delta.
    public let name: String?

    /// The JSON arguments delta.
    public let arguments: String?

    /// Initializes a function call delta.
    public init(name: String? = nil, arguments: String? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

/// Incremental tool call data streamed in a completion chunk.
public struct ToolCallDelta: Codable, Sendable, Equatable {
    /// The index used to reassemble streamed tool call fragments.
    public let index: Int?

    /// The tool call identifier delta.
    public let id: String?

    /// The tool type delta.
    public let type: String?

    /// The function call delta.
    public let function: FunctionCallDelta?

    /// Initializes a tool call delta.
    public init(
        index: Int? = nil,
        id: String? = nil,
        type: String? = nil,
        function: FunctionCallDelta? = nil
    ) {
        self.index = index
        self.id = id
        self.type = type
        self.function = function
    }
}

/// A structure representing the delta updates to a conversation choices stream.
public struct ChoiceDelta: Codable, Sendable, Equatable {
    /// The role delta.
    public let role: Role?

    /// The text content delta updates.
    public let content: String?

    /// The thinking/reasoning chain content delta updates.
    public let reasoningContent: String?

    /// The tool calls delta updates requested by the model.
    public let toolCalls: [ToolCallDelta]?

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }

    /// Initializes a choice delta.
    public init(
        role: Role? = nil,
        content: String? = nil,
        reasoningContent: String? = nil,
        toolCalls: [ToolCallDelta]? = nil
    ) {
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.toolCalls = toolCalls
    }
}
