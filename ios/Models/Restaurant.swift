import Foundation

struct Restaurant: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
    let address: String?
    let cuisine: String?
    let coverImageUrl: String?
    let googleMapsUrl: String?
    let instagramUrl: String?
    let createdBy: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case underscoreId = "_id"
        case name
        case description
        case address
        case cuisine
        case coverImageUrl
        case googleMapsUrl
        case instagramUrl
        case createdBy
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? c.decode(String.self, forKey: .underscoreId)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        cuisine = try c.decodeIfPresent(String.self, forKey: .cuisine)
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
        googleMapsUrl = try c.decodeIfPresent(String.self, forKey: .googleMapsUrl)
        instagramUrl = try c.decodeIfPresent(String.self, forKey: .instagramUrl)
        createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}
