import Foundation

@MainActor
final class RestaurantDetailViewModel: ObservableObject {
    @Published var restaurant: Restaurant?
    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var isSubmittingReview = false
    @Published var errorMessage: String?
    let currentUserId: String?

    private let restaurantService: RestaurantService
    private let reviewService: ReviewService
    private let restaurantId: String

    init(
        restaurantId: String,
        restaurantService: RestaurantService,
        reviewService: ReviewService,
        currentUserId: String?
    ) {
        self.restaurantId = restaurantId
        self.restaurantService = restaurantService
        self.reviewService = reviewService
        self.currentUserId = currentUserId
    }

    func isOwnReview(_ review: Review) -> Bool {
        guard let currentUserId else { return false }
        return review.user?.id == currentUserId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let restaurantCall = restaurantService.getRestaurant(id: restaurantId)
            async let reviewsCall = reviewService.getRestaurantReviews(restaurantId: restaurantId)
            restaurant = try await restaurantCall
            reviews = try await reviewsCall
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitReview(service: Double, price: Double, menu: Double, comment: String) async {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            errorMessage = "Il commento deve avere almeno 5 caratteri"
            return
        }

        isSubmittingReview = true
        defer { isSubmittingReview = false }

        do {
            _ = try await reviewService.createReview(
                restaurantId: restaurantId,
                payload: CreateReviewPayload(
                    serviceRating: service,
                    priceRating: price,
                    menuRating: menu,
                    comment: trimmed
                )
            )
            reviews = try await reviewService.getRestaurantReviews(restaurantId: restaurantId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateReview(reviewId: String, service: Double, price: Double, menu: Double, comment: String) async {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            errorMessage = "Il commento deve avere almeno 5 caratteri"
            return
        }

        isSubmittingReview = true
        defer { isSubmittingReview = false }

        do {
            _ = try await reviewService.updateReview(
                reviewId: reviewId,
                payload: UpdateReviewPayload(
                    serviceRating: service,
                    priceRating: price,
                    menuRating: menu,
                    comment: trimmed
                )
            )
            reviews = try await reviewService.getRestaurantReviews(restaurantId: restaurantId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteReview(reviewId: String) async {
        isSubmittingReview = true
        defer { isSubmittingReview = false }

        do {
            try await reviewService.deleteReview(reviewId: reviewId)
            reviews.removeAll { $0.id == reviewId }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
