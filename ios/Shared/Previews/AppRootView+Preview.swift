import SwiftUI

#if DEBUG
private enum AppRootPreviewFactory {
    static func livePreviewRoot() -> some View {
        let session = SessionManager()
        let client = APIClient(baseURL: AppConfig.apiBaseURL)
        session.restoreSession()

        return AppRootView(client: client)
            .environmentObject(session)
    }

    static func mockPreviewRoot(role: String) -> some View {
        let session = SessionManager()
        let client = APIClient(baseURL: URL(string: "https://example.com/api")!)

        session.currentUser = User(
            id: "preview-user",
            username: "preview",
            displayName: "Preview User",
            email: "preview@example.com",
            role: role
        )
        session.isAuthenticated = true

        return AppRootView(client: client)
            .environmentObject(session)
    }
}

@available(iOS 17.0, *)
#Preview("App Shell - Live API") {
    AppRootPreviewFactory.livePreviewRoot()
}

@available(iOS 17.0, *)
#Preview("App Shell - Mock Admin") {
    AppRootPreviewFactory.mockPreviewRoot(role: "admin")
}

@available(iOS 17.0, *)
#Preview("App Shell - Mock State Playground") {
    @Previewable @State var selectedRole = "user"

    VStack(alignment: .leading, spacing: 12) {
        Picker("Ruolo", selection: $selectedRole) {
            Text("User").tag("user")
            Text("Admin").tag("admin")
            Text("Superadmin").tag("superadmin")
        }
        .pickerStyle(.segmented)

        AppRootPreviewFactory.mockPreviewRoot(role: selectedRole)
    }
    .padding()
}
#endif
