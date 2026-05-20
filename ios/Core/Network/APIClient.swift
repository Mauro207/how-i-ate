import Foundation

protocol AccessTokenProviding: AnyObject {
    var accessToken: String? { get }
}

final class APIClient {
    private let baseURL: URL
    private weak var tokenProvider: AccessTokenProviding?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL, tokenProvider: AccessTokenProviding? = nil) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    func setTokenProvider(_ provider: AccessTokenProviding?) {
        tokenProvider = provider
    }

    func encodeBody<T: Encodable>(_ payload: T) throws -> Data {
        try encoder.encode(payload)
    }

    func send<T: Decodable>(_ request: APIRequest, responseType: T.Type = T.self) async throws -> T {
        let urlRequest = try buildURLRequest(from: request)
        let debugRequestId = UUID().uuidString.prefix(8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            debugLog("[\(debugRequestId)] Transport error: \(error.localizedDescription)")
            throw APIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            debugLog("[\(debugRequestId)] Invalid HTTP response for \(request.method.rawValue) \(urlRequest.url?.absoluteString ?? "-")")
            throw APIError.invalidResponse
        }

        debugLog("[\(debugRequestId)] \(request.method.rawValue) \(urlRequest.url?.absoluteString ?? "-") -> \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 401:
            debugLogResponseBody(data, requestId: debugRequestId, note: "401 body")
            throw APIError.unauthorized
        case 403:
            debugLogResponseBody(data, requestId: debugRequestId, note: "403 body")
            throw APIError.forbidden
        case 404:
            debugLogResponseBody(data, requestId: debugRequestId, note: "404 body")
            throw APIError.notFound
        default:
            debugLogResponseBody(data, requestId: debugRequestId, note: "error body")
            let message = parseServerMessage(from: data) ?? "Errore server (\(httpResponse.statusCode))"
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            debugLogResponseBody(data, requestId: debugRequestId, note: "decode body")
            debugLog("[\(debugRequestId)] Decoding target: \(String(describing: T.self))")
            debugLog("[\(debugRequestId)] Decoding error: \(describeDecodingError(error))")
            throw APIError.decoding(error)
        }
    }

    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        let fullPath = request.path.hasPrefix("/") ? String(request.path.dropFirst()) : request.path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(fullPath), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if request.requiresAuth, let token = tokenProvider?.accessToken, !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = request.body
        return urlRequest
    }

    private func parseServerMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["message"] as? String
        else {
            return nil
        }
        return message
    }

    private func describeDecodingError(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case let .keyNotFound(key, context):
                return "keyNotFound(\(key.stringValue)) path=\(codingPath(context.codingPath)) desc=\(context.debugDescription)"
            case let .typeMismatch(type, context):
                return "typeMismatch(\(type)) path=\(codingPath(context.codingPath)) desc=\(context.debugDescription)"
            case let .valueNotFound(type, context):
                return "valueNotFound(\(type)) path=\(codingPath(context.codingPath)) desc=\(context.debugDescription)"
            case let .dataCorrupted(context):
                return "dataCorrupted(path=\(codingPath(context.codingPath)) desc=\(context.debugDescription))"
            @unknown default:
                return "unknown DecodingError: \(decodingError.localizedDescription)"
            }
        }

        return error.localizedDescription
    }

    private func codingPath(_ path: [CodingKey]) -> String {
        if path.isEmpty {
            return "<root>"
        }
        return path.map { $0.stringValue }.joined(separator: ".")
    }

    private func debugLogResponseBody(_ data: Data, requestId: String.SubSequence, note: String) {
        let raw = String(data: data, encoding: .utf8) ?? "<body non UTF-8, \(data.count) bytes>"
        let maxLen = 2500
        let trimmed = raw.count > maxLen ? String(raw.prefix(maxLen)) + " ...<truncated>" : raw
        debugLog("[\(requestId)] \(note): \(trimmed)")
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[API DEBUG] \(message)")
#endif
    }
}
