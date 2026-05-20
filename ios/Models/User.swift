import Foundation

struct User: Decodable, Identifiable, Equatable {
    let id: String
    let username: String
    let displayName: String?
    let email: String
    let role: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case underscoreId = "_id"
        case username
        case displayName
        case email
        case role
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .underscoreId)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        role = try container.decode(String.self, forKey: .role)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    init(id: String, username: String, displayName: String?, email: String, role: String, createdAt: String? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.role = role
        self.createdAt = createdAt
    }
}
