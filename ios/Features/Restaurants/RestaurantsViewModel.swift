import Foundation

@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var topRankings: [RankingItem] = []
    @Published var isLoading = false
    @Published var isSubmittingSuggestion = false
    @Published var errorMessage: String?
    @Published var rankingErrorMessage: String?
    @Published var suggestionMessage: String?

    let restaurantService: RestaurantService
    let reviewService: ReviewService
    let rankingService: RankingService
    private let suggestionService: SuggestionService

    private static var cachedRestaurants: [Restaurant] = []
    private static var cachedTopRankings: [RankingItem] = []

    init(
        restaurantService: RestaurantService,
        reviewService: ReviewService,
        rankingService: RankingService,
        suggestionService: SuggestionService
    ) {
        self.restaurantService = restaurantService
        self.reviewService = reviewService
        self.rankingService = rankingService
        self.suggestionService = suggestionService
        restaurants = Self.cachedRestaurants
        topRankings = Self.cachedTopRankings
    }

    var recentRestaurants: [Restaurant] {
        Array(restaurants.sorted {
            ($0.createdAt ?? "") > ($1.createdAt ?? "")
        }.prefix(4))
    }

    var hasCachedContent: Bool {
        !restaurants.isEmpty || !topRankings.isEmpty
    }

    func load(forceRefresh: Bool = false) async {
        if hasCachedContent && !forceRefresh {
            errorMessage = nil
            rankingErrorMessage = nil
            return
        }

        let shouldShowBlockingLoader = !hasCachedContent
        if shouldShowBlockingLoader {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let loadedRestaurants = try await restaurantService.getRestaurants(forceRefresh: forceRefresh)
            restaurants = loadedRestaurants
            Self.cachedRestaurants = loadedRestaurants
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            if restaurants.isEmpty {
                restaurants = Self.cachedRestaurants
            }
        }

        do {
            let loadedRankings = try await rankingService.getGlobalRankings(forceRefresh: forceRefresh)
                .filter { !$0.restaurantId.isEmpty }
            let visibleRankings = Array(loadedRankings.prefix(5))
            topRankings = visibleRankings
            Self.cachedTopRankings = visibleRankings
            rankingErrorMessage = nil
        } catch {
            rankingErrorMessage = error.localizedDescription
            if topRankings.isEmpty {
                topRankings = Self.cachedTopRankings
            }
        }
    }

    func createSuggestion(
        name: String,
        description: String?,
        address: String?,
        cuisine: String?,
        googleMapsUrl: String?,
        instagramUrl: String?,
        serviceRating: Double,
        priceRating: Double,
        menuRating: Double,
        comment: String
    ) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.count >= 2 else {
            suggestionMessage = "Inserisci un nome luogo valido"
            return
        }

        guard trimmedComment.count >= 5 else {
            suggestionMessage = "Il commento deve avere almeno 5 caratteri"
            return
        }

        isSubmittingSuggestion = true
        defer { isSubmittingSuggestion = false }

        do {
            _ = try await suggestionService.createSuggestion(
                payload: CreateSuggestionPayload(
                    name: trimmedName,
                    description: description.trimmedNilIfEmpty,
                    address: address.trimmedNilIfEmpty,
                    cuisine: cuisine.trimmedNilIfEmpty,
                    googleMapsUrl: googleMapsUrl.trimmedNilIfEmpty,
                    instagramUrl: instagramUrl.trimmedNilIfEmpty,
                    review: SuggestionReviewPayload(
                        serviceRating: serviceRating,
                        priceRating: priceRating,
                        menuRating: menuRating,
                        comment: trimmedComment
                    )
                )
            )
            suggestionMessage = "Suggerimento inviato con successo"
        } catch {
            suggestionMessage = error.localizedDescription
        }
    }
}

private extension Optional where Wrapped == String {
    var trimmedNilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
