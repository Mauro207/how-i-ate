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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            let message = parseServerMessage(from: data) ?? "Errore server (\(httpResponse.statusCode))"
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
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
}
