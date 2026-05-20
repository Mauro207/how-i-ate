import Foundation

struct MessageResponse: Decodable {
    let message: String
}

struct LoginResponse: Decodable {
    let message: String
    let token: String
    let user: User
}

struct MeResponse: Decodable {
    let user: User
}

struct UsersResponse: Decodable {
    let users: [User]
}

struct RestaurantsResponse: Decodable {
    let count: Int
    let restaurants: [Restaurant]
}

struct RestaurantResponse: Decodable {
    let restaurant: Restaurant
}

struct RestaurantMutationResponse: Decodable {
    let message: String
    let restaurant: Restaurant
}

struct ReviewsResponse: Decodable {
    let count: Int
    let reviews: [Review]
}

struct ReviewResponse: Decodable {
    let message: String
    let review: Review
}

struct RankingsResponse: Decodable {
    let rankings: [RankingItem]
}

struct UserRankingsResponse: Decodable {
    let rankings: [UserRankingItem]
}

struct SuggestionResponse: Decodable {
    let message: String
    let suggestion: Suggestion
}

struct SuggestionsResponse: Decodable {
    let count: Int
    let suggestions: [Suggestion]
}

struct ApproveSuggestionResponse: Decodable {
    let message: String
    let restaurant: Restaurant
}
