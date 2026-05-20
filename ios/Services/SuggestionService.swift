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
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func createSuggestion(payload: CreateSuggestionPayload) async throws -> Suggestion {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "suggestions", method: .post, body: body)
        let response: SuggestionResponse = try await client.send(req)
        return response.suggestion
    }

    func getSuggestions() async throws -> [Suggestion] {
        let req = APIRequest(path: "suggestions", method: .get)
        let response: SuggestionsResponse = try await client.send(req)
        return response.suggestions
    }

    func approveSuggestion(id: String) async throws -> Restaurant {
        let req = APIRequest(path: "suggestions/\(id)/approve", method: .put, body: Data("{}".utf8))
        let response: ApproveSuggestionResponse = try await client.send(req)
        return response.restaurant
    }

    func rejectSuggestion(id: String) async throws {
        let req = APIRequest(path: "suggestions/\(id)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
    }
}
