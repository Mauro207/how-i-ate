import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Restaurant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let restaurantService: RestaurantService

    init(restaurantService: RestaurantService) {
        self.restaurantService = restaurantService
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

        do {
            results = try await restaurantService.searchRestaurants(query: trimmed)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
