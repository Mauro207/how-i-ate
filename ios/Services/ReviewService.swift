import Foundation

struct CreateReviewPayload: Encodable {
    let serviceRating: Double
    let priceRating: Double
    let menuRating: Double
    let comment: String
}

struct UpdateReviewPayload: Encodable {
    let serviceRating: Double?
    let priceRating: Double?
    let menuRating: Double?
    let comment: String?
}

final class ReviewService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func getRestaurantReviews(restaurantId: String) async throws -> [Review] {
        let req = APIRequest(path: "reviews/restaurant/\(restaurantId)", method: .get)
        let response: ReviewsResponse = try await client.send(req)
        return response.reviews
    }

    func createReview(restaurantId: String, payload: CreateReviewPayload) async throws -> Review {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "reviews/restaurant/\(restaurantId)", method: .post, body: body)
        let response: ReviewResponse = try await client.send(req)
        return response.review
    }

    func updateReview(reviewId: String, payload: UpdateReviewPayload) async throws -> Review {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "reviews/\(reviewId)", method: .put, body: body)
        let response: ReviewResponse = try await client.send(req)
        return response.review
    }

    func deleteReview(reviewId: String) async throws {
        let req = APIRequest(path: "reviews/\(reviewId)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
    }
}
