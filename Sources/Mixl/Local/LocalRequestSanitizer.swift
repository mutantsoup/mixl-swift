import Foundation
import os

/// Prepares cloud-shaped ``ChatCompletionRequest`` values for the local Foundation Models backend.
///
/// Sampling and reasoning parameters that Foundation Models does not expose are **stripped** with
/// an `os.Logger` info message so orchestrators can pass one request shape to both backends.
/// Semantic parameters (`tools`, JSON `response_format`, tool messages) remain **strict** and
/// throw ``MixlError/unsupportedParameter(_:)``.
enum LocalRequestSanitizer {
    private static let logger = Logger(subsystem: "com.mutantsoup.Mixl", category: "LocalInference")
    private static let backendName = "Apple Foundation Models"

    static func prepare(_ request: ChatCompletionRequest) throws -> ChatCompletionRequest {
        guard Model(rawValue: request.model).isAppleFoundation else {
            throw MixlError.modelNotSupported(model: request.model, backend: backendName)
        }

        try validateSemanticParameters(request)

        let loggedParameterNames = loggedIgnoredParameterNames(in: request)
        guard needsStripping(request) else {
            return request
        }

        for name in loggedParameterNames {
            logger.info(
                "Dropped unsupported local parameter `\(name)`; continuing with Apple Foundation Models defaults."
            )
        }

        return strippedRequest(from: request)
    }

    private static func validateSemanticParameters(_ request: ChatCompletionRequest) throws {
        if let tools = request.tools, !tools.isEmpty {
            throw MixlError.unsupportedParameter("tools")
        }
        if let responseFormat = request.responseFormat, responseFormat.type != .text {
            throw MixlError.unsupportedParameter("response_format")
        }
        if request.messages.contains(where: { $0.role == .tool || $0.toolCalls != nil }) {
            throw MixlError.unsupportedParameter("tool messages")
        }
    }

    private static func loggedIgnoredParameterNames(in request: ChatCompletionRequest) -> [String] {
        var names: [String] = []

        if request.thinking == true {
            names.append("thinking")
        }
        if request.reasoningEffort != nil {
            names.append("reasoning_effort")
        }
        if request.topP != nil {
            names.append("top_p")
        }
        if request.topK != nil {
            names.append("top_k")
        }
        if request.frequencyPenalty != nil {
            names.append("frequency_penalty")
        }
        if request.presencePenalty != nil {
            names.append("presence_penalty")
        }
        if request.repetitionPenalty != nil {
            names.append("repetition_penalty")
        }
        if request.stop?.isEmpty == false {
            names.append("stop")
        }
        if request.seed != nil {
            names.append("seed")
        }

        return names
    }

    private static func needsStripping(_ request: ChatCompletionRequest) -> Bool {
        request.thinking != nil
            || request.reasoningEffort != nil
            || request.topP != nil
            || request.topK != nil
            || request.frequencyPenalty != nil
            || request.presencePenalty != nil
            || request.repetitionPenalty != nil
            || request.stop?.isEmpty == false
            || request.seed != nil
    }

    private static func strippedRequest(from request: ChatCompletionRequest) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: request.model,
            messages: request.messages,
            thinking: nil,
            reasoningEffort: nil,
            temperature: request.temperature,
            topP: nil,
            topK: nil,
            frequencyPenalty: nil,
            presencePenalty: nil,
            repetitionPenalty: nil,
            maxCompletionTokens: request.maxCompletionTokens,
            maxTokens: request.maxTokens,
            stop: nil,
            seed: nil,
            stream: request.stream,
            tools: request.tools,
            responseFormat: request.responseFormat
        )
    }
}
