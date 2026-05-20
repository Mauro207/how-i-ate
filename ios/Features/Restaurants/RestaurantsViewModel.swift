import Foundation

@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let restaurantService: RestaurantService
    let reviewService: ReviewService

    init(restaurantService: RestaurantService, reviewService: ReviewService) {
        self.restaurantService = restaurantService
        self.reviewService = reviewService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            restaurants = try await restaurantService.getRestaurants()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
