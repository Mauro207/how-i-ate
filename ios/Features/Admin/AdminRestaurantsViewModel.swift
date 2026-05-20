import Foundation

@MainActor
final class AdminRestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let service: RestaurantService

    init(service: RestaurantService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            restaurants = try await service.getRestaurants()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(payload: RestaurantMutationPayload) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let restaurant = try await service.createRestaurant(payload: payload)
            restaurants.insert(restaurant, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(id: String, payload: RestaurantMutationPayload) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let restaurant = try await service.updateRestaurant(id: id, payload: payload)
            if let idx = restaurants.firstIndex(where: { $0.id == id }) {
                restaurants[idx] = restaurant
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: String) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await service.deleteRestaurant(id: id)
            restaurants.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
