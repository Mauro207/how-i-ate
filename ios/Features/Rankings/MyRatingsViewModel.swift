import Foundation

@MainActor
final class MyRatingsViewModel: ObservableObject {
    @Published private(set) var allItems: [UserRankingItem] = []
    @Published var items: [UserRankingItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showFilters = false
    @Published var includedCuisines: Set<String> = []

    private let service: RankingService
    private var loadedUserId: String?

    var availableCuisines: [String] {
        let cuisines = allItems.compactMap { item -> String? in
            guard let cuisine = item.cuisine?.trimmingCharacters(in: .whitespacesAndNewlines), !cuisine.isEmpty else {
                return nil
            }
            return cuisine
        }
        return Array(Set(cuisines)).sorted()
    }

    var hasActiveCuisineFilters: Bool {
        !includedCuisines.isEmpty
    }

    init(service: RankingService) {
        self.service = service
    }

    func toggleFilters() {
        showFilters.toggle()
    }

    func toggleCuisine(_ cuisine: String) {
        if includedCuisines.contains(cuisine) {
            includedCuisines.remove(cuisine)
        } else {
            includedCuisines.insert(cuisine)
        }
        applyFilters()
    }

    func isCuisineIncluded(_ cuisine: String) -> Bool {
        includedCuisines.contains(cuisine)
    }

    func load(userId: String?, forceRefresh: Bool = false) async {
        guard let userId, !userId.isEmpty else {
            allItems = []
            items = []
            loadedUserId = nil
            errorMessage = "Utente non disponibile"
            return
        }

        if loadedUserId != userId {
            includedCuisines = []
            showFilters = false
            if let cached = service.cachedUserRankings(userId: userId) {
                allItems = cached
                applyFilters()
            } else {
                allItems = []
                items = []
            }
            loadedUserId = userId
        } else if !forceRefresh, allItems.isEmpty, let cached = service.cachedUserRankings(userId: userId) {
            allItems = cached
            applyFilters()
        }

        let shouldShowBlockingLoader = allItems.isEmpty
        if shouldShowBlockingLoader {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            allItems = try await service.getUserRankings(userId: userId, forceRefresh: forceRefresh)
            applyFilters()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyFilters() {
        guard !includedCuisines.isEmpty else {
            items = allItems
            return
        }

        items = allItems.filter { item in
            guard let cuisine = item.cuisine?.trimmingCharacters(in: .whitespacesAndNewlines), !cuisine.isEmpty else {
                return false
            }
            return includedCuisines.contains(cuisine)
        }
    }
}
