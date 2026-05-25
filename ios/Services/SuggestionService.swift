import Foundation

struct SuggestionReviewPayload: Encodable {
    let serviceRating: Double
    let priceRating: Double
    let menuRating: Double
    let comment: String
}

struct CreateSuggestionPayload: Encodable {
    let name: String
    let description: String?
    let address: String?
    let cuisine: String?
    let googleMapsUrl: String?
    let instagramUrl: String?
    let review: SuggestionReviewPayload
}

final class SuggestionService {
    private struct CacheEntry<Value> {
        let value: Value
        let timestamp: Date
    }

    private let client: APIClient
    private let onRestaurantDataChanged: (() -> Void)?
    private let cacheTTL: TimeInterval = 60
    private var suggestionsCache: CacheEntry<[Suggestion]>?

    init(client: APIClient, onRestaurantDataChanged: (() -> Void)? = nil) {
        self.client = client
        self.onRestaurantDataChanged = onRestaurantDataChanged
    }

    func createSuggestion(payload: CreateSuggestionPayload) async throws -> Suggestion {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "suggestions", method: .post, body: body)
        let response: SuggestionResponse = try await client.send(req)
        invalidateSuggestionsCache()
        return response.suggestion
    }

    func cachedSuggestions() -> [Suggestion]? {
        guard let suggestionsCache, Date().timeIntervalSince(suggestionsCache.timestamp) < cacheTTL else {
            return nil
        }
        return suggestionsCache.value
    }

    func getSuggestions(forceRefresh: Bool = false) async throws -> [Suggestion] {
        if !forceRefresh, let cached = cachedSuggestions() {
            return cached
        }

        let req = APIRequest(path: "suggestions", method: .get)
        let response: SuggestionsResponse = try await client.send(req)
        suggestionsCache = CacheEntry(value: response.suggestions, timestamp: Date())
        return response.suggestions
    }

    func approveSuggestion(id: String) async throws -> Restaurant {
        let req = APIRequest(path: "suggestions/\(id)/approve", method: .put, body: Data("{}".utf8))
        let response: ApproveSuggestionResponse = try await client.send(req)
        invalidateSuggestionsCache()
        onRestaurantDataChanged?()
        return response.restaurant
    }

    func rejectSuggestion(id: String) async throws {
        let req = APIRequest(path: "suggestions/\(id)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
        invalidateSuggestionsCache()
    }

    func invalidateSuggestionsCache() {
        suggestionsCache = nil
    }
}
