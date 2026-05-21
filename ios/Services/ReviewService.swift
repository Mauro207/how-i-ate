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
    private var reviewsByRestaurantCache: [String: [Review]] = [:]
    private var reviewToRestaurantIndex: [String: String] = [:]

    init(client: APIClient) {
        self.client = client
    }

    func getRestaurantReviews(restaurantId: String, forceRefresh: Bool = false) async throws -> [Review] {
        if !forceRefresh, let cached = reviewsByRestaurantCache[restaurantId] {
            return cached
        }

        let req = APIRequest(path: "reviews/restaurant/\(restaurantId)", method: .get)
        let response: ReviewsResponse = try await client.send(req)
        reviewsByRestaurantCache[restaurantId] = response.reviews
        for review in response.reviews {
            reviewToRestaurantIndex[review.id] = restaurantId
        }
        return response.reviews
    }

    func createReview(restaurantId: String, payload: CreateReviewPayload) async throws -> Review {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "reviews/restaurant/\(restaurantId)", method: .post, body: body)
        let response: ReviewResponse = try await client.send(req)
        reviewsByRestaurantCache.removeValue(forKey: restaurantId)
        reviewToRestaurantIndex[response.review.id] = restaurantId
        return response.review
    }

    func updateReview(reviewId: String, payload: UpdateReviewPayload) async throws -> Review {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "reviews/\(reviewId)", method: .put, body: body)
        let response: ReviewResponse = try await client.send(req)
        if let restaurantId = reviewToRestaurantIndex[reviewId] {
            reviewsByRestaurantCache.removeValue(forKey: restaurantId)
        }
        return response.review
    }

    func deleteReview(reviewId: String) async throws {
        let req = APIRequest(path: "reviews/\(reviewId)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
        if let restaurantId = reviewToRestaurantIndex[reviewId] {
            reviewsByRestaurantCache.removeValue(forKey: restaurantId)
            reviewToRestaurantIndex.removeValue(forKey: reviewId)
        }
    }
}
