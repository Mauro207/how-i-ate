import SwiftUI

struct UsersManagementView: View {
    let authService: AuthService

    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var passwordInputs: [String: String] = [:]
    @State private var feedbackByUserId: [String: Feedback] = [:]
    @State private var savingUserId: String?

    private struct Feedback {
        let isSuccess: Bool
        let message: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    loadingCard
                } else if let errorMessage, users.isEmpty {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: errorMessage)
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .usersGlassCard()
                } else if users.isEmpty {
                    UnavailableStateView(title: "Nessun utente", systemImage: "person.2", message: "Non ci sono utenti da mostrare")
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .usersGlassCard()
                } else {
                    usersList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(usersBackground)
        .navigationTitle("Gestisci utenti")
        .task { await loadUsers() }
        .refreshable { await loadUsers() }
    }

    private var usersBackground: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.indigo.opacity(0.10),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Caricamento utenti...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .usersGlassCard()
    }

    private var usersList: some View {
        VStack(spacing: 10) {
            ForEach(users) { user in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.displayName?.nilIfEmpty ?? user.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(user.email.nilIfEmpty ?? "Email non disponibile")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Text(user.role)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(roleColor(for: user.role))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(roleColor(for: user.role).opacity(0.14), in: Capsule())
                    }

                    HStack(spacing: 8) {
                        SecureField("Nuova password (min 6)", text: bindingForPassword(user.id))
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.75))
                            )

                        Button {
                            Task { await updatePassword(for: user.id) }
                        } label: {
                            if savingUserId == user.id {
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: 84, height: 42)
                            } else {
                                Text("Aggiorna")
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 84, height: 42)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(Color.indigo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .disabled(savingUserId == user.id)
                    }

                    if let feedback = feedbackByUserId[user.id] {
                        Text(feedback.message)
                            .font(.caption)
                            .foregroundStyle(feedback.isSuccess ? Color.green : Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .padding(12)
        .usersGlassCard()
    }

    private func roleColor(for role: String) -> Color {
        switch role {
        case "superadmin": return .indigo
        case "admin": return .blue
        default: return .secondary
        }
    }

    private func bindingForPassword(_ userId: String) -> Binding<String> {
        Binding(
            get: { passwordInputs[userId] ?? "" },
            set: {
                passwordInputs[userId] = $0
                feedbackByUserId[userId] = nil
            }
        )
    }

    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            users = try await authService.getAllUsers()
            errorMessage = nil
        } catch {
            if users.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updatePassword(for userId: String) async {
        let password = (passwordInputs[userId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard password.count >= 6 else {
            feedbackByUserId[userId] = Feedback(isSuccess: false, message: "La password deve avere almeno 6 caratteri")
            return
        }

        savingUserId = userId
        defer { savingUserId = nil }

        do {
            let message = try await authService.updateUserPassword(userId: userId, password: password)
            feedbackByUserId[userId] = Feedback(isSuccess: true, message: message)
            passwordInputs[userId] = ""
        } catch {
            feedbackByUserId[userId] = Feedback(isSuccess: false, message: error.localizedDescription)
        }
    }
}

private struct UsersGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.indigo.opacity(0.06)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

private extension View {
    func usersGlassCard() -> some View {
        modifier(UsersGlassCardModifier())
    }
}
