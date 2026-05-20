import Foundation

final class AuthTokenProvider: AccessTokenProviding {
    private let keychain = KeychainStore()
    private let tokenKey = "jwt"

    var accessToken: String? {
        keychain.read(for: tokenKey)
    }
}
