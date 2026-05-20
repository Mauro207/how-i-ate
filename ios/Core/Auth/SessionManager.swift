import Foundation

@MainActor
final class SessionManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false

    private let keychain = KeychainStore()
    private let tokenKey = "jwt"

    var accessToken: String? {
        keychain.read(for: tokenKey)
    }

    func restoreSession() {
        isAuthenticated = accessToken != nil
    }

    func setSession(token: String, user: User) {
        keychain.save(token, for: tokenKey)
        currentUser = user
        isAuthenticated = true
    }

    func clearSession() {
        keychain.delete(for: tokenKey)
        currentUser = nil
        isAuthenticated = false
    }
}
