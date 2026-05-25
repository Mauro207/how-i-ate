import Foundation

final class RankingService {
    private struct CacheEntry<Value> {
        let value: Value
        let timestamp: Date
    }

    private let client: APIClient
    private let cacheTTL: TimeInterval = 120
    private var globalRankingsCache: CacheEntry<[RankingItem]>?
    private var userRankingsCache: [String: CacheEntry<[UserRankingItem]>] = [:]

    init(client: APIClient) {
        self.client = client
    }

    func cachedGlobalRankings() -> [RankingItem]? {
        guard let cache = globalRankingsCache, isFresh(cache.timestamp) else { return nil }
        return cache.value
    }

    func cachedUserRankings(userId: String) -> [UserRankingItem]? {
        guard let cache = userRankingsCache[userId], isFresh(cache.timestamp) else { return nil }
        return cache.value
    }

    func getGlobalRankings(forceRefresh: Bool = false) async throws -> [RankingItem] {
        if !forceRefresh, let cached = cachedGlobalRankings() {
            return cached
        }

        let req = APIRequest(path: "reviews/rankings/global", method: .get)
        let response: RankingsResponse = try await client.send(req)
        let rankings = response.rankings.sorted(by: RankingCalculator.sort)
        globalRankingsCache = CacheEntry(value: rankings, timestamp: Date())
        return rankings
    }

    func getUserRankings(userId: String, forceRefresh: Bool = false) async throws -> [UserRankingItem] {
        if !forceRefresh, let cached = cachedUserRankings(userId: userId) {
            return cached
        }

        let req = APIRequest(path: "reviews/rankings/user/\(userId)", method: .get)
        let response: UserRankingsResponse = try await client.send(req)
        userRankingsCache[userId] = CacheEntry(value: response.rankings, timestamp: Date())
        return response.rankings
    }

    func invalidateRankings() {
        globalRankingsCache = nil
        userRankingsCache.removeAll()
    }

    func invalidateUserRankings(userId: String) {
        userRankingsCache.removeValue(forKey: userId)
        globalRankingsCache = nil
    }

    private func isFresh(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) < cacheTTL
    }
}
