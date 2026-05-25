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
    @Published var isLoadingDefaultSections = false
    @Published var errorMessage: String?
    @Published var randomRestaurants: [Restaurant] = []
    @Published var totalRestaurants = 0

    private let restaurantService: RestaurantService
    private let authService: AuthService
    private var resultsCache: [String: [SearchResultItem]] = [:]
    private var searchGeneration = 0

    init(restaurantService: RestaurantService, authService: AuthService) {
        self.restaurantService = restaurantService
        self.authService = authService
    }

    func loadDefaultSections(forceRefresh: Bool = false) async {
        isLoadingDefaultSections = true
        defer { isLoadingDefaultSections = false }

        do {
            let restaurants = try await restaurantService.getRestaurants(forceRefresh: forceRefresh)
            totalRestaurants = restaurants.count
            randomRestaurants = Array(restaurants.shuffled().prefix(5))
        } catch {
            totalRestaurants = 0
            randomRestaurants = []
        }
    }

    func search(forceRefresh: Bool = false) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        let cacheKey = trimmed.lowercased()
        searchGeneration += 1
        let generation = searchGeneration

        if !forceRefresh, let cached = resultsCache[cacheKey] {
            results = cached
            errorMessage = nil
            return
        }

        let shouldShowBlockingLoader = results.isEmpty
        if shouldShowBlockingLoader {
            isLoading = true
        }
        defer {
            if generation == searchGeneration {
                isLoading = false
            }
        }

        async let restaurantsTask: Result<[Restaurant], Error> = {
            do {
                return .success(try await restaurantService.searchRestaurants(query: trimmed, forceRefresh: forceRefresh))
            } catch {
                return .failure(error)
            }
        }()

        async let usersTask: Result<[UserSearchResult], Error> = {
            do {
                return .success(try await authService.searchUsers(query: trimmed, forceRefresh: forceRefresh))
            } catch {
                return .failure(error)
            }
        }()

        let (restaurantResult, usersResult) = await (restaurantsTask, usersTask)
        guard generation == searchGeneration, trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

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

        let combinedResults = restaurantItems + userItems
        results = combinedResults
        resultsCache[cacheKey] = combinedResults

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
