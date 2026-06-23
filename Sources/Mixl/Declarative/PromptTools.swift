import Foundation

// MARK: - Tool schema DSL

/// A single parameter in a declaratively-defined tool's JSON Schema.
public struct Field {
    let name: String
    let type: JSONType
    let description: String?
    let required: Bool
    let enumValues: [String]?

    /// Declares a tool parameter.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - type: The JSON Schema type.
    ///   - description: A human-readable description for the model.
    ///   - required: Whether the parameter is required. Defaults to `false`.
    ///   - enumValues: Optional set of allowed string values.
    public init(
        _ name: String,
        _ type: JSONType,
        _ description: String? = nil,
        required: Bool = false,
        enumValues: [String]? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.enumValues = enumValues
    }
}

/// A result builder for composing tool parameter ``Field`` values with `if` / `for`.
@resultBuilder
public enum FieldBuilder {
    public static func buildExpression(_ expression: Field) -> [Field] { [expression] }
    public static func buildBlock(_ components: [Field]...) -> [Field] { components.flatMap { $0 } }
    public static func buildOptional(_ component: [Field]?) -> [Field] { component ?? [] }
    public static func buildEither(first component: [Field]) -> [Field] { component }
    public static func buildEither(second component: [Field]) -> [Field] { component }
    public static func buildArray(_ components: [[Field]]) -> [Field] { components.flatMap { $0 } }
}

/// Declaratively defines a function tool, building its JSON Schema from composed ``Field`` values.
///
/// ```swift
/// FunctionTool("get_time", "Get the current time for a city") {
///     Field("city", .string, "City name", required: true)
/// }
/// ```
public func FunctionTool(
    _ name: String,
    _ description: String? = nil,
    @FieldBuilder fields: () -> [Field] = { [] }
) -> Tool {
    let fields = fields()
    let parameters: JSONSchema?
    if fields.isEmpty {
        parameters = nil
    } else {
        let properties = Dictionary(uniqueKeysWithValues: fields.map { field in
            (field.name, JSONSchema(type: field.type, description: field.description, enumValues: field.enumValues))
        })
        let required = fields.filter(\.required).map(\.name)
        parameters = JSONSchema(type: .object, properties: properties, required: required.isEmpty ? nil : required)
    }
    return Tool(function: FunctionDefinition(name: name, description: description, parameters: parameters))
}

/// A result builder for composing `Tool` values with `if` / `for`.
@resultBuilder
public enum ToolBuilder {
    public static func buildExpression(_ expression: Tool) -> [Tool] { [expression] }
    public static func buildBlock(_ components: [Tool]...) -> [Tool] { components.flatMap { $0 } }
    public static func buildOptional(_ component: [Tool]?) -> [Tool] { component ?? [] }
    public static func buildEither(first component: [Tool]) -> [Tool] { component }
    public static func buildEither(second component: [Tool]) -> [Tool] { component }
    public static func buildArray(_ components: [[Tool]]) -> [Tool] { components.flatMap { $0 } }
}

extension PromptContent {
    /// Appends tools declared with the ``ToolBuilder`` DSL.
    ///
    /// ```swift
    /// .tools {
    ///     FunctionTool("get_time", "Current time for a city") {
    ///         Field("city", .string, "City name", required: true)
    ///     }
    /// }
    /// ```
    public func tools(@ToolBuilder _ tools: () -> [Tool]) -> some PromptContent {
        self.tools(tools())
    }
}
