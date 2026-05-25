import Foundation

struct RestaurantMutationPayload: Encodable {
    let name: String
    let description: String?
    let address: String?
    let cuisine: String?
    let coverImageUrl: String?
    let googleMapsUrl: String?
    let instagramUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case address
        case cuisine
        case coverImageUrl
        case googleMapsUrl
        case instagramUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeNullable(description, forKey: .description)
        try container.encodeNullable(address, forKey: .address)
        try container.encodeNullable(cuisine, forKey: .cuisine)
        try container.encodeNullable(coverImageUrl, forKey: .coverImageUrl)
        try container.encodeNullable(googleMapsUrl, forKey: .googleMapsUrl)
        try container.encodeNullable(instagramUrl, forKey: .instagramUrl)
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeNullable(_ value: String?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

struct GooglePlaceSuggestion: Decodable, Identifiable, Equatable {
    let placeId: String
    let description: String
    let mainText: String
    let secondaryText: String

    var id: String { placeId }
}

struct GooglePlaceDetails: Decodable, Equatable {
    let placeId: String
    let name: String
    let city: String
    let mapsUrl: String
}

private struct GooglePlacesAutocompleteResponse: Decodable {
    let suggestions: [GooglePlaceSuggestion]
}

final class RestaurantService {
    private struct CacheEntry<Value> {
        let value: Value
        let timestamp: Date
    }

    private let client: APIClient
    private let rankingService: RankingService?
    private let listCacheTTL: TimeInterval = 120
    private let searchCacheTTL: TimeInterval = 90
    private let googleCacheTTL: TimeInterval = 300
    private var restaurantsCache: CacheEntry<[Restaurant]>?
    private var restaurantByIdCache: [String: CacheEntry<Restaurant>] = [:]
    private var searchCache: [String: CacheEntry<[Restaurant]>] = [:]
    private var googleSuggestionsCache: [String: CacheEntry<[GooglePlaceSuggestion]>] = [:]
    private var googleDetailsCache: [String: CacheEntry<GooglePlaceDetails>] = [:]

    init(client: APIClient, rankingService: RankingService? = nil) {
        self.client = client
        self.rankingService = rankingService
    }

    func cachedRestaurants() -> [Restaurant]? {
        guard let restaurantsCache, isFresh(restaurantsCache.timestamp, ttl: listCacheTTL) else { return nil }
        return restaurantsCache.value
    }

    func cachedRestaurant(id: String) -> Restaurant? {
        guard let cache = restaurantByIdCache[id], isFresh(cache.timestamp, ttl: listCacheTTL) else { return nil }
        return cache.value
    }

    func getRestaurants(forceRefresh: Bool = false) async throws -> [Restaurant] {
        if !forceRefresh, let cached = cachedRestaurants() {
            return cached
        }

        let req = APIRequest(path: "restaurants", method: .get)
        let response: RestaurantsResponse = try await client.send(req)
        restaurantsCache = CacheEntry(value: response.restaurants, timestamp: Date())
        for restaurant in response.restaurants {
            restaurantByIdCache[restaurant.id] = CacheEntry(value: restaurant, timestamp: Date())
        }
        return response.restaurants
    }

    func getRestaurant(id: String, forceRefresh: Bool = false) async throws -> Restaurant {
        if !forceRefresh, let cached = cachedRestaurant(id: id) {
            return cached
        }

        let req = APIRequest(path: "restaurants/\(id)", method: .get)
        let response: RestaurantResponse = try await client.send(req)
        restaurantByIdCache[id] = CacheEntry(value: response.restaurant, timestamp: Date())
        return response.restaurant
    }

    func searchRestaurants(query: String, forceRefresh: Bool = false) async throws -> [Restaurant] {
        let cacheKey = normalizedCacheKey(query)
        guard !cacheKey.isEmpty else { return [] }

        if !forceRefresh,
           let cached = searchCache[cacheKey],
           isFresh(cached.timestamp, ttl: searchCacheTTL) {
            return cached.value
        }

        let req = APIRequest(
            path: "restaurants/search",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let response: RestaurantsResponse = try await client.send(req)
        searchCache[cacheKey] = CacheEntry(value: response.restaurants, timestamp: Date())
        for restaurant in response.restaurants {
            restaurantByIdCache[restaurant.id] = CacheEntry(value: restaurant, timestamp: Date())
        }
        return response.restaurants
    }

    func getGooglePlaceSuggestions(query: String, forceRefresh: Bool = false) async throws -> [GooglePlaceSuggestion] {
        let cacheKey = normalizedCacheKey(query)
        guard !cacheKey.isEmpty else { return [] }

        if !forceRefresh,
           let cached = googleSuggestionsCache[cacheKey],
           isFresh(cached.timestamp, ttl: googleCacheTTL) {
            return cached.value
        }

        let req = APIRequest(
            path: "restaurants/places/autocomplete",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let response: GooglePlacesAutocompleteResponse = try await client.send(req)
        googleSuggestionsCache[cacheKey] = CacheEntry(value: response.suggestions, timestamp: Date())
        return response.suggestions
    }

    func getGooglePlaceDetails(placeId: String, forceRefresh: Bool = false) async throws -> GooglePlaceDetails {
        if !forceRefresh,
           let cached = googleDetailsCache[placeId],
           isFresh(cached.timestamp, ttl: googleCacheTTL) {
            return cached.value
        }

        let req = APIRequest(
            path: "restaurants/places/details",
            method: .get,
            queryItems: [URLQueryItem(name: "placeId", value: placeId)]
        )
        let details: GooglePlaceDetails = try await client.send(req)
        googleDetailsCache[placeId] = CacheEntry(value: details, timestamp: Date())
        return details
    }

    func createRestaurant(payload: RestaurantMutationPayload) async throws -> Restaurant {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "restaurants", method: .post, body: body)
        let response: RestaurantMutationResponse = try await client.send(req)
        invalidateRestaurantCaches()
        restaurantByIdCache[response.restaurant.id] = CacheEntry(value: response.restaurant, timestamp: Date())
        return response.restaurant
    }

    func updateRestaurant(id: String, payload: RestaurantMutationPayload) async throws -> Restaurant {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "restaurants/\(id)", method: .put, body: body)
        let response: RestaurantMutationResponse = try await client.send(req)
        invalidateRestaurantCaches()
        restaurantByIdCache[id] = CacheEntry(value: response.restaurant, timestamp: Date())
        return response.restaurant
    }

    func deleteRestaurant(id: String) async throws {
        let req = APIRequest(path: "restaurants/\(id)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
        invalidateRestaurantCaches()
        restaurantByIdCache.removeValue(forKey: id)
    }

    func invalidateRestaurantCaches() {
        restaurantsCache = nil
        searchCache.removeAll()
        rankingService?.invalidateRankings()
    }

    private func normalizedCacheKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isFresh(_ timestamp: Date, ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}
