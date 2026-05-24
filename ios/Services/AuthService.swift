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

@MainActor
final class AuthService {
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
        return response.user
    }

    func searchUsers(query: String) async throws -> [UserSearchResult] {
        let req = APIRequest(
            path: "auth/users/search",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let response: UserSearchResponse = try await client.send(req)
        return response.users
    }

    func getAllUsers() async throws -> [User] {
        let req = APIRequest(path: "auth/users", method: .get)
        let response: UsersResponse = try await client.send(req)
        return response.users
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
}
