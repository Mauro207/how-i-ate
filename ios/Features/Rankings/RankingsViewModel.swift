import Foundation

@MainActor
final class RankingsViewModel: ObservableObject {
    @Published var rankings: [RankingItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RankingService

    init(service: RankingService) {
        self.service = service
        rankings = service.cachedGlobalRankings() ?? []
    }

    func loadGlobal(forceRefresh: Bool = false) async {
        if !forceRefresh, rankings.isEmpty, let cached = service.cachedGlobalRankings() {
            rankings = cached
        }

        let shouldShowBlockingLoader = rankings.isEmpty
        if shouldShowBlockingLoader {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            rankings = try await service.getGlobalRankings(forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
