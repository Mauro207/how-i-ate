import Foundation

struct RestaurantMutationPayload: Encodable {
    let name: String
    let description: String?
    let address: String?
    let cuisine: String?
    let coverImageUrl: String?
    let googleMapsUrl: String?
    let instagramUrl: String?
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
    private let client: APIClient
    private var restaurantsCache: [Restaurant]?
    private var restaurantByIdCache: [String: Restaurant] = [:]
    private var searchCache: [String: [Restaurant]] = [:]

    init(client: APIClient) {
        self.client = client
    }

    func getRestaurants(forceRefresh: Bool = false) async throws -> [Restaurant] {
        if !forceRefresh, let restaurantsCache {
            return restaurantsCache
        }

        let req = APIRequest(path: "restaurants", method: .get)
        let response: RestaurantsResponse = try await client.send(req)
        restaurantsCache = response.restaurants
        for restaurant in response.restaurants {
            restaurantByIdCache[restaurant.id] = restaurant
        }
        return response.restaurants
    }

    func getRestaurant(id: String, forceRefresh: Bool = false) async throws -> Restaurant {
        if !forceRefresh, let cached = restaurantByIdCache[id] {
            return cached
        }

        let req = APIRequest(path: "restaurants/\(id)", method: .get)
        let response: RestaurantResponse = try await client.send(req)
        restaurantByIdCache[id] = response.restaurant
        return response.restaurant
    }

    func searchRestaurants(query: String, forceRefresh: Bool = false) async throws -> [Restaurant] {
        let cacheKey = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !forceRefresh, let cached = searchCache[cacheKey] {
            return cached
        }

        let req = APIRequest(
            path: "restaurants/search",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let response: RestaurantsResponse = try await client.send(req)
        searchCache[cacheKey] = response.restaurants
        return response.restaurants
    }

    func getGooglePlaceSuggestions(query: String) async throws -> [GooglePlaceSuggestion] {
        let req = APIRequest(
            path: "restaurants/places/autocomplete",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let response: GooglePlacesAutocompleteResponse = try await client.send(req)
        return response.suggestions
    }

    func getGooglePlaceDetails(placeId: String) async throws -> GooglePlaceDetails {
        let req = APIRequest(
            path: "restaurants/places/details",
            method: .get,
            queryItems: [URLQueryItem(name: "placeId", value: placeId)]
        )
        return try await client.send(req)
    }

    func createRestaurant(payload: RestaurantMutationPayload) async throws -> Restaurant {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "restaurants", method: .post, body: body)
        let response: RestaurantMutationResponse = try await client.send(req)
        invalidateRestaurantCaches()
        restaurantByIdCache[response.restaurant.id] = response.restaurant
        return response.restaurant
    }

    func updateRestaurant(id: String, payload: RestaurantMutationPayload) async throws -> Restaurant {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "restaurants/\(id)", method: .put, body: body)
        let response: RestaurantMutationResponse = try await client.send(req)
        invalidateRestaurantCaches()
        restaurantByIdCache[id] = response.restaurant
        return response.restaurant
    }

    func deleteRestaurant(id: String) async throws {
        let req = APIRequest(path: "restaurants/\(id)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
        invalidateRestaurantCaches()
        restaurantByIdCache.removeValue(forKey: id)
    }

    private func invalidateRestaurantCaches() {
        restaurantsCache = nil
        searchCache.removeAll()
    }
}
