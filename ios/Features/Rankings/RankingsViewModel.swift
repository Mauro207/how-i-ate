import Foundation

@MainActor
final class RankingsViewModel: ObservableObject {
    @Published var rankings: [RankingItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RankingService

    init(service: RankingService) {
        self.service = service
    }

    func loadGlobal() async {
        isLoading = true
        defer { isLoading = false }

        do {
            rankings = try await service.getGlobalRankings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
