import Foundation

struct ReviewUser: Decodable, Identifiable, Equatable {
    let id: String
    let username: String
    let displayName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case underscoreId = "_id"
        case username
        case displayName
        case email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? c.decode(String.self, forKey: .underscoreId)
        username = try c.decode(String.self, forKey: .username)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
    }
}

struct Review: Decodable, Identifiable, Equatable {
    let id: String
    let restaurant: String?
    let user: ReviewUser?
    let serviceRating: Double
    let priceRating: Double
    let menuRating: Double
    let comment: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case underscoreId = "_id"
        case restaurant
        case user
        case serviceRating
        case priceRating
        case menuRating
        case comment
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? c.decode(String.self, forKey: .underscoreId)
        restaurant = try c.decodeIfPresent(String.self, forKey: .restaurant)
        user = try c.decodeIfPresent(ReviewUser.self, forKey: .user)
        serviceRating = try c.decode(Double.self, forKey: .serviceRating)
        priceRating = try c.decode(Double.self, forKey: .priceRating)
        menuRating = try c.decode(Double.self, forKey: .menuRating)
        comment = try c.decode(String.self, forKey: .comment)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}
