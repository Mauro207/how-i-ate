import Foundation

struct RankingItem: Decodable, Equatable {
    let restaurantId: String
    let restaurantName: String
    let cuisine: String?
    let address: String?
    let averageRating: Double
    let reviewCount: Int

    private struct RestaurantRef: Decodable {
        let id: String?
        let name: String?
        let cuisine: String?
        let address: String?

        enum CodingKeys: String, CodingKey {
            case id
            case underscoreId = "_id"
            case name
            case cuisine
            case address
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(String.self, forKey: .id)
                ?? c.decodeIfPresent(String.self, forKey: .underscoreId)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            cuisine = try c.decodeIfPresent(String.self, forKey: .cuisine)
            address = try c.decodeIfPresent(String.self, forKey: .address)
        }
    }

    enum CodingKeys: String, CodingKey {
        case restaurantId
        case underscoreId = "_id"
        case restaurantName
        case name
        case restaurant
        case cuisine
        case address
        case averageRating
        case avgRating
        case reviewCount
        case count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let nestedRestaurant = try? c.decode(RestaurantRef.self, forKey: .restaurant)

        let restaurantIdValue = try? c.decode(String.self, forKey: .restaurantId)
        let underscoreIdValue = try? c.decode(String.self, forKey: .underscoreId)
        restaurantId = restaurantIdValue ?? underscoreIdValue ?? nestedRestaurant?.id ?? ""

        let restaurantNameValue = try? c.decode(String.self, forKey: .restaurantName)
        let nameValue = try? c.decode(String.self, forKey: .name)
        restaurantName = restaurantNameValue ?? nameValue ?? nestedRestaurant?.name ?? "Luogo"

        cuisine = (try? c.decode(String.self, forKey: .cuisine)) ?? nestedRestaurant?.cuisine
        address = (try? c.decode(String.self, forKey: .address)) ?? nestedRestaurant?.address

        if let value = (try? c.decode(Double.self, forKey: .averageRating))
            ?? (try? c.decode(Double.self, forKey: .avgRating)) {
            averageRating = value
        } else if let value = (try? c.decode(Int.self, forKey: .averageRating))
            ?? (try? c.decode(Int.self, forKey: .avgRating)) {
            averageRating = Double(value)
        } else {
            averageRating = 0
        }

        let reviewCountValue = try? c.decode(Int.self, forKey: .reviewCount)
        let countValue = try? c.decode(Int.self, forKey: .count)
        reviewCount = reviewCountValue ?? countValue ?? 0
    }
}

struct UserRankingItem: Decodable, Equatable {
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
