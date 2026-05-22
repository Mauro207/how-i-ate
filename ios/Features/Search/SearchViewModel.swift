import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    enum SearchResultItem: Identifiable, Equatable {
        case restaurant(Restaurant)
        case user(UserSearchResult)

        var id: String {
            switch self {
            case let .restaurant(restaurant):
                return "restaurant-\(restaurant.id)"
            case let .user(user):
                return "user-\(user.id)"
            }
        }
    }

    @Published var query = ""
    @Published var results: [SearchResultItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let restaurantService: RestaurantService
    private let authService: AuthService

    init(restaurantService: RestaurantService, authService: AuthService) {
        self.restaurantService = restaurantService
        self.authService = authService
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        async let restaurantsTask: Result<[Restaurant], Error> = {
            do {
                return .success(try await restaurantService.searchRestaurants(query: trimmed))
            } catch {
                return .failure(error)
            }
        }()

        async let usersTask: Result<[UserSearchResult], Error> = {
            do {
                return .success(try await authService.searchUsers(query: trimmed))
            } catch {
                return .failure(error)
            }
        }()

        let (restaurantResult, usersResult) = await (restaurantsTask, usersTask)

        let restaurantItems: [SearchResultItem]
        let userItems: [SearchResultItem]

        switch restaurantResult {
        case let .success(restaurants):
            restaurantItems = restaurants.map(SearchResultItem.restaurant)
        case .failure:
            restaurantItems = []
        }

        switch usersResult {
        case let .success(users):
            userItems = users.map(SearchResultItem.user)
        case .failure:
            userItems = []
        }

        results = restaurantItems + userItems

        let restaurantFailed: Bool
        if case .failure = restaurantResult {
            restaurantFailed = true
        } else {
            restaurantFailed = false
        }

        let usersFailed: Bool
        if case .failure = usersResult {
            usersFailed = true
        } else {
            usersFailed = false
        }

        if restaurantFailed, usersFailed {
            errorMessage = "Errore nel caricamento dei risultati"
        } else {
            errorMessage = nil
        }
    }
}
