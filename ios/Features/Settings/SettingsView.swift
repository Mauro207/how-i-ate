import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionManager
    let authService: AuthService
    let suggestionService: SuggestionService
    let disableAutoLoad: Bool

    init(authService: AuthService, suggestionService: SuggestionService, disableAutoLoad: Bool = false) {
        self.authService = authService
        self.suggestionService = suggestionService
        self.disableAutoLoad = disableAutoLoad
    }

    private var displayName: String {
        session.currentUser?.displayName ?? session.currentUser?.username ?? "Utente"
    }

    private var email: String {
        session.currentUser?.email ?? "Email non disponibile"
    }

    private var role: String {
        session.currentUser?.role ?? "-"
    }

    private var isSuperAdmin: Bool {
        session.currentUser?.role == "superadmin"
    }

    private var isAdminOrSuperAdmin: Bool {
        guard let role = session.currentUser?.role else { return false }
        return role == "admin" || role == "superadmin"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    quickActionsCard
                    accountCard
                    logoutCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(settingsBackground)
            .navigationTitle("Impostazioni")
            .task {
                guard !disableAutoLoad else { return }
                if session.currentUser == nil {
                    _ = try? await authService.fetchMe()
                }
            }
        }
    }

    private var settingsBackground: some View {
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

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Text(initials)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.indigo, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Divider()
                .opacity(0.5)

            HStack(spacing: 10) {
                Image(systemName: "person.badge.key")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.indigo)
                    .frame(width: 30, height: 30)
                    .background(Color.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ruolo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(role)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .settingsGlassCard()
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Azioni rapide")
                .font(.title3.weight(.bold))

            NavigationLink {
                UpdatesView()
            } label: {
                quickActionRow(
                    title: "Ultimi aggiornamenti",
                    subtitle: "Novita, fix e miglioramenti rilasciati",
                    icon: "sparkles"
                )
            }
            .buttonStyle(.plain)

            if isAdminOrSuperAdmin {
                NavigationLink {
                    AdminSuggestionsView(
                        viewModel: AdminSuggestionsViewModel(service: suggestionService)
                    )
                } label: {
                    quickActionRow(
                        title: "Gestione suggerimenti",
                        subtitle: "Approva o rifiuta suggerimenti ricevuti",
                        icon: "tray.full"
                    )
                }
                .buttonStyle(.plain)
            }

            if isSuperAdmin {
                NavigationLink {
                    UsersManagementView(authService: authService)
                } label: {
                    quickActionRow(
                        title: "Gestisci utenti",
                        subtitle: "Visualizza utenti e aggiorna password",
                        icon: "person.2"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .settingsGlassCard()
    }

    private func quickActionRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .frame(width: 40, height: 40)
                .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var logoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessione")
                .font(.title3.weight(.bold))

            Button(role: .destructive) {
                authService.logout()
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .settingsDestructiveButtonBackground()
        }
        .padding(16)
        .settingsGlassCard()
    }

    private var initials: String {
        let parts = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let value = String(parts).uppercased()
        return value.isEmpty ? "U" : value
    }
}

private struct SettingsGlassCardModifier: ViewModifier {
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

private struct SettingsDestructiveButtonBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.red.opacity(0.18)).interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            content
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private extension View {
    func settingsGlassCard() -> some View {
        modifier(SettingsGlassCardModifier())
    }

    func settingsDestructiveButtonBackground() -> some View {
        modifier(SettingsDestructiveButtonBackgroundModifier())
    }
}
