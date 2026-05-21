import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let previewMode: Bool

    init(authService: AuthService, previewMode: Bool = false) {
        self.authService = authService
        self.previewMode = previewMode
    }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading
    }

    func login() async {
        if previewMode {
            errorMessage = "Anteprima attiva: login disabilitato"
            return
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Inserisci email e password"
            return
        }

        email = trimmedEmail
        password = trimmedPassword

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
