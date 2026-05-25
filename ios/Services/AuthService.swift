import Foundation

struct RegisterPayload: Encodable {
    let username: String
    let email: String
    let password: String
}

struct LoginPayload: Encodable {
    let email: String
    let password: String
}

struct UpdateProfilePayload: Encodable {
    let displayName: String
}

struct CreateUserPayload: Encodable {
    let username: String
    let email: String
    let password: String
}

private struct CreateUserResponse: Decodable {
    let message: String?
    let user: User
}

@MainActor
final class AuthService {
    private struct CacheEntry<Value> {
        let value: Value
        let timestamp: Date
    }

    private static let cacheTTL: TimeInterval = 120
    private static var userSearchCache: [String: CacheEntry<[UserSearchResult]>] = [:]
    private static var allUsersCache: CacheEntry<[User]>?

    private let client: APIClient
    private let session: SessionManager

    init(client: APIClient, session: SessionManager) {
        self.client = client
        self.session = session
    }

    func login(email: String, password: String) async throws {
        let body = try client.encodeBody(LoginPayload(email: email, password: password))
        let req = APIRequest(path: "auth/login", method: .post, body: body, requiresAuth: false)
        let response: LoginResponse = try await client.send(req)
        session.setSession(token: response.token, user: response.user)
    }

    func register(username: String, email: String, password: String) async throws {
        let body = try client.encodeBody(RegisterPayload(username: username, email: email, password: password))
        let req = APIRequest(path: "auth/register", method: .post, body: body, requiresAuth: false)
        let response: LoginResponse = try await client.send(req)
        session.setSession(token: response.token, user: response.user)
        Self.invalidateUserCaches()
    }

    func fetchMe() async throws -> User {
        let req = APIRequest(path: "auth/me", method: .get)
        let response: MeResponse = try await client.send(req)
        session.currentUser = response.user
        session.isAuthenticated = true
        return response.user
    }

    func updateProfile(displayName: String) async throws -> User {
        let body = try client.encodeBody(UpdateProfilePayload(displayName: displayName))
        let req = APIRequest(path: "auth/profile", method: .put, body: body)
        let response: MeResponse = try await client.send(req)
        session.currentUser = response.user
        Self.invalidateUserCaches()
        return response.user
    }

    func searchUsers(query: String, forceRefresh: Bool = false) async throws -> [UserSearchResult] {
        let cacheKey = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cacheKey.isEmpty else { return [] }

        if !forceRefresh,
           let cached = Self.userSearchCache[cacheKey],
           Self.isFresh(cached.timestamp) {
            return cached.value
        }

        let req = APIRequest(
            path: "auth/users/search",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let response: UserSearchResponse = try await client.send(req)
        Self.userSearchCache[cacheKey] = CacheEntry(value: response.users, timestamp: Date())
        return response.users
    }

    func cachedAllUsers() -> [User]? {
        guard let cache = Self.allUsersCache, Self.isFresh(cache.timestamp) else { return nil }
        return cache.value
    }

    func getAllUsers(forceRefresh: Bool = false) async throws -> [User] {
        if !forceRefresh, let cached = cachedAllUsers() {
            return cached
        }

        let req = APIRequest(path: "auth/users", method: .get)
        let response: UsersResponse = try await client.send(req)
        Self.allUsersCache = CacheEntry(value: response.users, timestamp: Date())
        return response.users
    }

    func createUser(username: String, email: String, password: String) async throws -> User {
        let payload = CreateUserPayload(
            username: username,
            email: email,
            password: password
        )
        let body = try client.encodeBody(payload)
        let req = APIRequest(path: "auth/create-user", method: .post, body: body)
        let response: CreateUserResponse = try await client.send(req)
        Self.invalidateUserCaches()
        return response.user
    }

    func updateUserPassword(userId: String, password: String) async throws -> String {
        struct UpdateUserPasswordPayload: Encodable {
            let password: String
        }

        let body = try client.encodeBody(UpdateUserPasswordPayload(password: password))
        let req = APIRequest(path: "auth/users/\(userId)/password", method: .put, body: body)
        let response: MessageResponse = try await client.send(req)
        return response.message
    }

    func logout() {
        session.clearSession()
    }

    private static func invalidateUserCaches() {
        userSearchCache.removeAll()
        allUsersCache = nil
    }

    private static func isFresh(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) < cacheTTL
    }
}
