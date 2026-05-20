import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionManager
    let authService: AuthService

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Text(session.currentUser?.displayName ?? session.currentUser?.username ?? "Utente")
                    Text(session.currentUser?.email ?? "")
                        .foregroundStyle(.secondary)
                    Text("Ruolo: \(session.currentUser?.role ?? "-")")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Logout", role: .destructive) {
                        authService.logout()
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                if session.currentUser == nil {
                    _ = try? await authService.fetchMe()
                }
            }
        }
    }
}
