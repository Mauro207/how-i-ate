import Foundation

@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var topRankings: [RankingItem] = []
    @Published var isLoading = false
    @Published var isSubmittingSuggestion = false
    @Published var errorMessage: String?
    @Published var suggestionMessage: String?

    let restaurantService: RestaurantService
    let reviewService: ReviewService
    private let rankingService: RankingService
    private let suggestionService: SuggestionService

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
    }

    var recentRestaurants: [Restaurant] {
        restaurants.sorted {
            ($0.createdAt ?? "") > ($1.createdAt ?? "")
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let restaurantsCall = restaurantService.getRestaurants()
            async let rankingsCall = rankingService.getGlobalRankings()

            restaurants = try await restaurantsCall
            topRankings = Array((try await rankingsCall).prefix(3))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
