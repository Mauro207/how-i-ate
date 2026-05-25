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
    private struct CacheEntry<Value> {
        let value: Value
        let timestamp: Date
    }

    private let client: APIClient
    private let rankingService: RankingService?
    private let cacheTTL: TimeInterval = 90
    private var reviewsByRestaurantCache: [String: CacheEntry<[Review]>] = [:]
    private var reviewToRestaurantIndex: [String: String] = [:]

    init(client: APIClient, rankingService: RankingService? = nil) {
        self.client = client
        self.rankingService = rankingService
    }

    func cachedRestaurantReviews(restaurantId: String) -> [Review]? {
        guard let cache = reviewsByRestaurantCache[restaurantId], Date().timeIntervalSince(cache.timestamp) < cacheTTL else {
            return nil
        }
        return cache.value
    }

    func getRestaurantReviews(restaurantId: String, forceRefresh: Bool = false) async throws -> [Review] {
        if !forceRefresh, let cached = cachedRestaurantReviews(restaurantId: restaurantId) {
            return cached
        }

        let req = APIRequest(path: "reviews/restaurant/\(restaurantId)", method: .get)
        let response: ReviewsResponse = try await client.send(req)
        reviewsByRestaurantCache[restaurantId] = CacheEntry(value: response.reviews, timestamp: Date())
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
        rankingService?.invalidateRankings()
        return response.review
    }

    func updateReview(reviewId: String, payload: UpdateReviewPayload) async throws -> Review {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "reviews/\(reviewId)", method: .put, body: body)
        let response: ReviewResponse = try await client.send(req)
        if let restaurantId = reviewToRestaurantIndex[reviewId] {
            reviewsByRestaurantCache.removeValue(forKey: restaurantId)
        }
        rankingService?.invalidateRankings()
        return response.review
    }

    func deleteReview(reviewId: String) async throws {
        let req = APIRequest(path: "reviews/\(reviewId)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
        if let restaurantId = reviewToRestaurantIndex[reviewId] {
            reviewsByRestaurantCache.removeValue(forKey: restaurantId)
            reviewToRestaurantIndex.removeValue(forKey: reviewId)
        }
        rankingService?.invalidateRankings()
    }
}
