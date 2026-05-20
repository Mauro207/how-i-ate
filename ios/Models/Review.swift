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

    private struct EntityRef: Decodable {
        let id: String?

        enum CodingKeys: String, CodingKey {
            case id
            case underscoreId = "_id"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(String.self, forKey: .id)
                ?? c.decodeIfPresent(String.self, forKey: .underscoreId)
        }
    }

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
        if let restaurantId = try c.decodeIfPresent(String.self, forKey: .restaurant) {
            restaurant = restaurantId
        } else if let restaurantRef = try c.decodeIfPresent(EntityRef.self, forKey: .restaurant) {
            restaurant = restaurantRef.id
        } else {
            restaurant = nil
        }

        if let userObject = try c.decodeIfPresent(ReviewUser.self, forKey: .user) {
            user = userObject
        } else {
            user = nil
        }

        serviceRating = try Self.decodeFlexibleDouble(from: c, key: .serviceRating)
        priceRating = try Self.decodeFlexibleDouble(from: c, key: .priceRating)
        menuRating = try Self.decodeFlexibleDouble(from: c, key: .menuRating)
        comment = try c.decode(String.self, forKey: .comment)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    private static func decodeFlexibleDouble(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Double {
        if let value = try container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        return 0
    }
}
