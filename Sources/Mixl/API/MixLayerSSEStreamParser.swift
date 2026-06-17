import Foundation

/// Represents the parsed outcomes of a single Server-Sent Events (SSE) data line.
enum ParsedEvent: Equatable {
    /// A completion chunk containing the delta of text or reasoning.
    case chunk(ChatCompletionChunk)
    /// Indicates the event stream has terminated.
    case done
    /// Represents an empty line or non-data heartbeat event.
    case empty
}

/// A thread-safe parser to buffer and process Server-Sent Events (SSE) streams from the MixLayer API.
actor MixLayerSSEStreamParser {
    private var buffer = ""

    /// Initializes a new instance of the parser.
    init() {}

    func parse(line: String) throws -> ParsedEvent {
        buffer += line

        // Find the first line terminator
        guard let newlineRange = buffer.rangeOfCharacter(from: CharacterSet(charactersIn: "\n\r")) else {
            return .empty
        }

        let lineToParse = String(buffer[..<newlineRange.lowerBound])
        
        // Remove parsed portion from buffer (consuming the character range including the newline)
        buffer = String(buffer[newlineRange.upperBound...])

        let trimmed = lineToParse.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .empty
        }

        if trimmed == "data: [DONE]" {
            return .done
        }

        if trimmed.hasPrefix("data: ") {
            let jsonString = String(trimmed.dropFirst(6))
            guard let data = jsonString.data(using: .utf8) else {
                return .empty
            }
            let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
            return .chunk(chunk)
        }

        return .empty
    }
}
