import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Inserisci email e password"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.login(email: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
