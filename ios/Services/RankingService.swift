import Foundation

final class RankingService {
    private let client: APIClient
    private var globalRankingsCache: [RankingItem]?

    init(client: APIClient) {
        self.client = client
    }

    func getGlobalRankings(forceRefresh: Bool = false) async throws -> [RankingItem] {
        if !forceRefresh, let globalRankingsCache {
            return globalRankingsCache
        }

        let req = APIRequest(path: "reviews/rankings/global", method: .get)
        let response: RankingsResponse = try await client.send(req)
        let rankings = response.rankings.sorted(by: RankingCalculator.sort)
        globalRankingsCache = rankings
        return rankings
    }

    func getUserRankings(userId: String) async throws -> [UserRankingItem] {
        let req = APIRequest(path: "reviews/rankings/user/\(userId)", method: .get)
        let response: UserRankingsResponse = try await client.send(req)
        return response.rankings
    }
}
