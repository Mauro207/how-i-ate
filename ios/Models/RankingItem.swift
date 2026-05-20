import Foundation

struct RankingItem: Codable, Equatable {
    let restaurantId: String
    let restaurantName: String
    let cuisine: String?
    let address: String?
    let averageRating: Double
    let reviewCount: Int
}

struct UserRankingItem: Codable, Equatable {
    let restaurantId: String
    let restaurantName: String
    let cuisine: String?
    let address: String?
    let averageRating: Double
    let serviceRating: Double
    let priceRating: Double
    let menuRating: Double
    let comment: String
    let createdAt: String?
    let reviewCount: Int
}
