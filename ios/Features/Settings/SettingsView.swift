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

private struct UpdatesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ultimi aggiornamenti")
                    .font(.title3.weight(.bold))

                VStack(alignment: .leading, spacing: 10) {
                    updateRow(title: "Design iOS 26", subtitle: "Aggiornate home, ricerca, ranking, impostazioni e dettaglio luogo.")
                    updateRow(title: "Classifiche", subtitle: "La valutazione media e ora piu visibile negli item ranking.")
                    updateRow(title: "Gestione luoghi", subtitle: "Migliorata validazione URL e modifica campi opzionali.")
                }
            }
            .padding(16)
            .settingsGlassCard()
            .padding(16)
        }
        .background(settingsScreenBackground)
        .navigationTitle("Aggiornamenti")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func updateRow(title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .frame(width: 28, height: 28)
                .background(Color.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct UsersManagementView: View {
    let authService: AuthService

    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedUser: User?
    @State private var password = ""
    @State private var isUpdatingPassword = false
    @State private var showCreateUserSheet = false
    @State private var newUsername = ""
    @State private var newEmail = ""
    @State private var newPassword = ""
    @State private var isCreatingUser = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Caricamento utenti...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .settingsGlassCard()
                } else if let errorMessage {
                    statusBanner(errorMessage, color: .red, icon: "exclamationmark.triangle.fill")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Utenti")
                                    .font(.title3.weight(.bold))
                                Text("\(users.count) utenti registrati")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            Button {
                                resetCreateUserForm()
                                showCreateUserSheet = true
                            } label: {
                                Label("Nuovo", systemImage: "plus")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(Color.indigo.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.indigo)
                        }

                        ForEach(users) { user in
                            Button {
                                selectedUser = user
                                password = ""
                                successMessage = nil
                            } label: {
                                userRow(user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .settingsGlassCard()
                }

                if let successMessage {
                    statusBanner(successMessage, color: .green, icon: "checkmark.circle.fill")
                }
            }
            .padding(16)
        }
        .background(settingsScreenBackground)
        .navigationTitle("Gestisci utenti")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadUsers() }
        .sheet(item: $selectedUser) { user in
            NavigationStack {
                Form {
                    Section("Utente") {
                        Text(user.displayName ?? user.username)
                        Text(user.email)
                            .foregroundStyle(.secondary)
                    }

                    Section("Nuova password") {
                        SecureField("Password", text: $password)
                    }

                    Section {
                        Button {
                            Task { await updatePassword(for: user) }
                        } label: {
                            if isUpdatingPassword {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Aggiorna password")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdatingPassword)
                    }
                }
                .navigationTitle("Password")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCreateUserSheet) {
            NavigationStack {
                Form {
                    Section("Dati utente") {
                        TextField("Username", text: $newUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Email", text: $newEmail)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                        SecureField("Password", text: $newPassword)
                    }

                    Section {
                        Button {
                            Task { await createUser() }
                        } label: {
                            if isCreatingUser {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Crea utente")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(!canCreateUser || isCreatingUser)
                    }
                }
                .navigationTitle("Nuovo utente")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") {
                            showCreateUserSheet = false
                        }
                        .disabled(isCreatingUser)
                    }
                }
            }
            .presentationDetents([.large])
        }
    }

    private var canCreateUser: Bool {
        !newUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func userRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            Text(initials(for: user))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.indigo, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(user.role)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.indigo.opacity(0.10), in: Capsule())
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusBanner(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .settingsGlassCard()
    }

    private func loadUsers(forceRefresh: Bool = false) async {
        if !forceRefresh, users.isEmpty, let cached = authService.cachedAllUsers() {
            users = cached
        }

        let shouldShowBlockingLoader = users.isEmpty
        if shouldShowBlockingLoader {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            users = try await authService.getAllUsers(forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updatePassword(for user: User) async {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassword.isEmpty else { return }

        isUpdatingPassword = true
        defer { isUpdatingPassword = false }

        do {
            successMessage = try await authService.updateUserPassword(userId: user.id, password: trimmedPassword)
            selectedUser = nil
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createUser() async {
        let username = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else { return }

        isCreatingUser = true
        defer { isCreatingUser = false }

        do {
            let user = try await authService.createUser(
                username: username,
                email: email,
                password: password
            )
            users.insert(user, at: 0)
            successMessage = "Utente creato con successo"
            errorMessage = nil
            showCreateUserSheet = false
            resetCreateUserForm()
            await loadUsers(forceRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetCreateUserForm() {
        newUsername = ""
        newEmail = ""
        newPassword = ""
        errorMessage = nil
        successMessage = nil
    }

    private func initials(for user: User) -> String {
        let source = user.displayName?.isEmpty == false ? user.displayName ?? user.username : user.username
        let value = String(source.prefix(2)).uppercased()
        return value.isEmpty ? "U" : value
    }
}

private var settingsScreenBackground: some View {
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
