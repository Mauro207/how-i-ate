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
        Array(restaurants.sorted {
            ($0.createdAt ?? "") > ($1.createdAt ?? "")
        }.prefix(5))
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // In linea con Angular: se i ristoranti non arrivano, la home e in errore.
        do {
            restaurants = try await restaurantService.getRestaurants()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            restaurants = []
        }

        // La classifica non deve bloccare la visibilita degli ultimi ristoranti.
        do {
            topRankings = Array((try await rankingService.getGlobalRankings()).prefix(3))
            rankingErrorMessage = nil
        } catch {
            topRankings = []
            rankingErrorMessage = error.localizedDescription
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
