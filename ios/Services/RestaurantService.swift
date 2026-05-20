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

final class RestaurantService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func getRestaurants() async throws -> [Restaurant] {
        let req = APIRequest(path: "restaurants", method: .get)
        let response: RestaurantsResponse = try await client.send(req)
        return response.restaurants
    }

    func getRestaurant(id: String) async throws -> Restaurant {
        let req = APIRequest(path: "restaurants/\(id)", method: .get)
        let response: RestaurantResponse = try await client.send(req)
        return response.restaurant
    }

    func searchRestaurants(query: String) async throws -> [Restaurant] {
        let req = APIRequest(
            path: "restaurants/search",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let response: RestaurantsResponse = try await client.send(req)
        return response.restaurants
    }

    func createRestaurant(payload: RestaurantMutationPayload) async throws -> Restaurant {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "restaurants", method: .post, body: body)
        let response: RestaurantMutationResponse = try await client.send(req)
        return response.restaurant
    }

    func updateRestaurant(id: String, payload: RestaurantMutationPayload) async throws -> Restaurant {
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "restaurants/\(id)", method: .put, body: body)
        let response: RestaurantMutationResponse = try await client.send(req)
        return response.restaurant
    }

    func deleteRestaurant(id: String) async throws {
        let req = APIRequest(path: "restaurants/\(id)", method: .delete)
        _ = try await client.send(req, responseType: MessageResponse.self)
    }
}
