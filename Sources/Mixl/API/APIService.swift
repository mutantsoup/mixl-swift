import Foundation

/// A concrete network-backed implementation of the `MixLayerService` protocol.
///
/// Sends HTTP requests to the MixLayer server using standard `URLSession`.
internal struct APIService: MixLayerService {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession

    /// Initializes a new instance of the API service.
    ///
    /// - Parameters:
    ///   - apiKey: The API key used for HTTP headers.
    ///   - baseURL: The base server URL.
    ///   - session: The `URLSession` instance to perform data transfers.
    init(apiKey: String, baseURL: URL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        let urlRequest = try makeURLRequest(for: request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw MixLayerError.network(error.localizedDescription)
        }

        _ = try validateHTTPResponse(response, data: data)

        do {
            return try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw MixLayerError.decodingFailed(error.localizedDescription)
        }
    }

    func createChatCompletionStream(
        request: ChatCompletionRequest
    ) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let urlRequest = try makeURLRequest(for: request)

        return AsyncThrowingStream(ChatCompletionChunk.self) { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw MixLayerError.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        let errorData = try await Self.collectData(from: bytes)
                        throw MixLayerErrorParser.httpError(
                            statusCode: httpResponse.statusCode,
                            data: errorData
                        )
                    }

                    let parser = SSEStreamParser()
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            break
                        }

                        let parsed = try parser.parse(line: line + "\n")
                        switch parsed {
                        case .chunk(let chunk):
                            continuation.yield(chunk)
                        case .done:
                            continuation.finish()
                            return
                        case .empty:
                            break
                        }
                    }
                    continuation.finish()
                } catch let error as MixLayerError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: MixLayerError.network(error.localizedDescription))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func makeURLRequest(for request: ChatCompletionRequest) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw MixLayerError.encodingFailed(error.localizedDescription)
        }

        return urlRequest
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MixLayerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MixLayerErrorParser.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return httpResponse
    }

    private static func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }
}
