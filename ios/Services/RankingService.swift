import Foundation

final class RankingService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func getGlobalRankings() async throws -> [RankingItem] {
        let req = APIRequest(path: "reviews/rankings/global", method: .get)
        let response: RankingsResponse = try await client.send(req)
        return response.rankings.sorted(by: RankingCalculator.sort)
    }

    func getUserRankings(userId: String) async throws -> [UserRankingItem] {
        let req = APIRequest(path: "reviews/rankings/user/\(userId)", method: .get)
        let response: UserRankingsResponse = try await client.send(req)
        return response.rankings
    }
}
