import Foundation

@MainActor
final class MyRatingsViewModel: ObservableObject {
    @Published var items: [UserRankingItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RankingService

    init(service: RankingService) {
        self.service = service
    }

    func load(userId: String?) async {
        guard let userId, !userId.isEmpty else {
            items = []
            errorMessage = "Utente non disponibile"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            items = try await service.getUserRankings(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
